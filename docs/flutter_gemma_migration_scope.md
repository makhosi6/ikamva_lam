# Scoping document: migrate primary on-device LLM to `flutter_gemma`

**Branch:** `feature/flutter-gemma-engine` (work happens here; merge via PR when ready.)

**Package:** [flutter_gemma](https://pub.dev/packages/flutter_gemma) (current line in docs: `flutter_gemma: ^0.13.5`; pin exact version in `pubspec.yaml` at implementation time.)

**Goal:** Replace the **only shipped** on-device inference path with **`flutter_gemma`** (MediaPipe / LiteRT-LM as implemented by the plugin), **remove the `native/` tree** (llama.cpp / `llama-cli` / GGUF workflow), and update all repository documentation to describe the new engine. Keep the **`LlmEngine`** abstraction so call sites (`LlmService.instance.generate`, optional streaming) stay stable.

**Product invariant (entire app, all releases):** **On-device AI only.** There is **no server-side LLM inference** and **no hybrid or fallback** that sends prompts or activations to a remote model. **Model weights** are **not** embedded in the APK/IPA (store size). They are fetched **once per device** over **HTTPS** using a compile-time `IKAMVA_MODEL_DOWNLOAD_URL`, then stored locally by **`flutter_gemma`** and reused across sessions; if the on-disk copy is missing or corrupt, the app **re-downloads** the same URL. Network use for **non–AI-core** needs (e.g. optional sync) remains separate and documented elsewhere.

**Branch product policy (this milestone):**

- **On-device Gemma as the “author”:** Learner-facing **generated** material is produced **entirely on device** via `flutter_gemma`—the same *kind* of conversational, model-authored experience users expect from hosted assistants, but **without** any cloud model. The app should not depend on hand-authored dynamic copy where generation is feasible; static assets remain acceptable only where explicitly allowed (e.g. branding, non-generative reference data, or legal/chrome strings—list and minimize exceptions during implementation).
- **HTTP model delivery:** Production code installs via **`FlutterGemma.installModel`…`fromNetwork`** using **`IKAMVA_MODEL_DOWNLOAD_URL`** (and optional **`IKAMVA_HF_TOKEN`** for gated Hugging Face URLs). Weights persist in the plugin sandbox; **`getActiveModel`** re-opens them between launches, with **re-install** if open fails.
- **Safety on every output:** Any **model-generated** text or JSON that reaches the learner must pass **`ChildFriendlyContentGate`** (fast rule checks plus the existing Gemma JSON sentiment path where applicable), consistent with `learner_app/lib/safety/child_friendly_content_gate.dart`.
- **Caching first:** Use **persistent caches** (e.g. `SharedPreferences`, Drift, or file-backed blobs) with stable keys and version bumps so the app does **not** re-call the model for the same logical content. Existing patterns (such as hub daily topics keyed by calendar day) should be generalized where other features today regenerate too often.
- **Structured prompts:** Every **content-generation** prompt must state the **expected output shape** explicitly (field names, JSON-only requirement, and a minimal example object or schema sentence) so parsers (`LlmOutputFilters`, `jsonDecode`, gate material extraction) stay reliable.

---

## 1. Problem statement

The learner app resolves an engine in `LlmService._createEngine()` (`learner_app/lib/llm/llm_service.dart`):

- **`IKAMVA_USE_STUB_LLM=1`** → `StubLlmEngine`
- Else on **Android / iOS** → **`FlutterGemmaLlmEngine`** (HTTPS → `FlutterGemma.installModel`…`fromNetwork`, then `getActiveModel`)
- Else (e.g. desktop `flutter test` host) → **`StubLlmEngine`**

**Historical note:** an earlier **`ProcessLlmEngine`** + **`native/`** + GGUF / `llama-cli` path existed for hackathon velocity; it has been **removed** in favour of **`flutter_gemma`** and **network-delivered** `.task` weights.

**Desired state:** Run on-device inference through **`flutter_gemma`’s** supported model formats (e.g. `.task` per their matrix), installing into the plugin’s expected location via **`fromNetwork`** at first use (and on recovery), then the **Modern API** (`FlutterGemma.getActiveModel`, `createSession`, streaming where applicable).

---

## 2. Current architecture (relevant parts)

| Layer | Role |
|--------|------|
| `LlmEngine` | `ensureLoaded()`, `generate(LlmGenerateRequest)`, `dispose()` |
| `LlmGenerateRequest` | `prompt`, optional `maxTokens`, `contextSize`, `stopSequences` (post-processed after inference) |
| `LlmService` | Singleton; `configure(SettingsStore)`, `ensureReady()`, `generate`, `tryOpenGenerateStream`, `invalidateCachedEngine` |
| `FlutterGemmaLlmEngine` | `flutter_gemma` install + `InferenceModel` session per `generate` |
| Callers | `task_queue_service`, `ai_hint_coordinator`, `child_friendly_content_gate`, `insight_job`, `daily_topics_service`, `answer_normalisation_service`, settings test UI, etc. |

**Streaming:** `StreamingLlmCapability` exists; `tryOpenGenerateStream` returns a stream only if the active engine implements it. `flutter_gemma` supports async chat generation (`generateChatResponseAsync`) — a good fit for a later `FlutterGemmaLlmEngine` + streaming.

---

## 3. Target architecture

1. **Dependency:** Add `flutter_gemma` to `learner_app/pubspec.yaml` and complete **per-platform setup** from the package readme (iOS already `16.0` and static frameworks in this repo; verify Android manifest / ProGuard, web `index.html` scripts if web is in scope).

2. **Initialization:** Call `FlutterGemma.initialize(...)` early in `main.dart`; pass **`huggingFaceToken`** when using gated Hugging Face URLs (compile-time `IKAMVA_HF_TOKEN` / CI secrets — do not log or expose in learner UI).

3. **New engine implementation:** e.g. `FlutterGemmaLlmEngine implements LlmEngine` (and optionally `StreamingLlmCapability`):

   - **`ensureLoaded`:** Try **`getActiveModel`**; on failure, **`installModel`…`fromNetwork`** with the configured URL, then open again. Progress may be forwarded to UI callbacks.
   - **`generate`:** Map each `LlmGenerateRequest` to a **session** (stateless, one completion) or a **fresh chat** with optional `systemInstruction` if we split prompts later. Apply **stop sequence trimming** in Dart to preserve the same contract as today’s post-processing. Preserve **`LlmOutputFilters.takeThroughFirstBalancedJson`** where JSON is still the contract.
   - **`dispose`:** Close model/session per plugin lifecycle.

4. **Engine selection in `LlmService`:** **Production builds** use **`FlutterGemmaLlmEngine`** on mobile once a **`IKAMVA_MODEL_DOWNLOAD_URL`** is compiled in. A **`StubLlmEngine`** remains for **automated tests and CI** where the plugin is not used. **`ProcessLlmEngine`** and **`native/`** are **removed**.

5. **Model policy:** Choose a **default inference URL** (family, size) aligned with **download size**, RAM, and quality. Document **store listing / privacy** (first-run download). Use **CI secrets** for tokens when URLs are gated.

6. **Repo hygiene:** Delete **`./native`** (build scripts, `LLAMA_CPP_REF`, docs that only serve subprocess inference) and scrub references from **README**, **TASKS**, **spec**, CI, and any scripts that pointed at `native/build/bin/llama-cli`.

---

## 4. Gap analysis

| Area | Today | With `flutter_gemma` |
|------|--------|----------------------|
| Weights | GGUF + `llama-cli` | `.task` / etc. (not GGUF) — **HTTPS download** at runtime; **persisted** by plugin; **no** weights in APK |
| Chat templates | Prompted as one string in CLI | Plugin / MediaPipe may handle templates for Type 1 files; Type 2 needs manual formatting — **validate against our prompt assets** |
| Stop sequences | Post-process truncate | Same post-process; verify streaming |
| Context / max tokens | `-c`, `-n` on CLI | Map to `getActiveModel(maxTokens: …)` and session/chat params |
| CI / headless | Optional stub; no GPU in many CI runners | **`StubLlmEngine`** (or fakes) in CI; optional device-only integration suite with real weights |
| Desktop | Subprocess if binary present | `flutter_gemma` desktop uses **LiteRT-LM `.litertlm` only** — different from mobile `.task` in some cases |
| Dynamic content | Mix of generation + seeded/static | **Policy:** generative paths own learner-facing copy; audit **seed DB / assets** to replace or narrow static narrative where product requires “all Gemma” |
| Safety | Gate used on many paths | **Mandatory** gate on **every** user-visible model output before show/store |
| Repeat calls | Some features may regenerate | **Cache** by logical key + version; invalidate on policy or model bump |

---

## 5. Decisions to lock before coding

**Locked for this branch (2026-04-20):**

1. **Default model:** **Gemma 3 1B IT** (mobile **`.task`**, `ModelType.gemmaIt`) — pick an HTTPS artifact URL; see `learner_app/lib/llm/gemma_model_config.dart` and **`OBTAINING_MODELS.txt`**.
2. **Delivery:** Compile **`IKAMVA_MODEL_DOWNLOAD_URL`** (and optional **`IKAMVA_HF_TOKEN`**) via `.env` / CI — **no** `pubspec` weight assets.
3. **Target platforms:** **Android + iOS** for on-device LLM this milestone; **web/desktop** inference **out of scope** (stub or plugin limitations).

**Still product-owned / partial:**

4. **Exceptions to “all generated”:** Enumerate **non-generated** strings (chrome, legal, fixed IDs) vs **generate → gate → cache** content — see migration tasks **A.5**.
5. **Cache matrix:** Per-feature keys and gate-fail behaviour — see **A.6** (hub prefs bumped to `hub_daily_topics_v4`).
6. **Streaming UI:** Engine supports `tryOpenGenerateStream` on mobile; learner-facing streamed UI is **TASKS §17.2** follow-up.

---

## 6. Risks

- **Binary size and install UX:** Bundled models **increase APK/IPA** dramatically; may approach store or cellular download limits—choose smallest viable model and monitor **compressed** size. First launch may still show **“preparing model”** while copying from asset to plugin storage; surface progress if the API exposes it.
- **Prompt / JSON contract:** If model output format drifts, JSON extraction and safety gates may need prompt tuning.
- **iOS large models:** Memory entitlements and file sharing flags per plugin README.
- **Version drift:** Pin `flutter_gemma` and re-run platform setup when upgrading.
- **Device heterogeneity:** Mid-range phones may OOM or throttle; need **CPU fallback**, **reduced `maxTokens`**, and clear “model not ready” UX tied to existing **low-RAM** / settings knobs where applicable.
- **Double inference cost:** Features that **generate** then run **gate sentiment** (second `LlmService` call) increase latency and battery use—mitigate with **caching**, **batching** (already used for hub topics), and conservative token limits on gate prompts.
- **Stale caches:** After **model or prompt version** changes, old cached strings may be wrong tone or format—centralize a **`content_cache_version`** (or per-feature bump constants) and document invalidation.

---

## 7. Additional areas to plan (recommended)

These are not a second-class backlog; they prevent production surprises and should be assigned alongside core engine work.

### 7.1 Resilience and degraded experience

- **No model / bad install:** If the **download URL** is missing, the install fails, or on-disk weights are corrupt (e.g. user cleared app data), show a **blocking** error and route to **Preparing AI** / retry download—**no** silent stub for child-facing flows on mobile.
- **Offline / airplane mode:** Core **inference must work** without network after install (assets are local).
- **Low disk space:** Plugin may need headroom when copying/unpacking; surface a clear error if install fails.
- **Timeouts:** `LlmService.generate` callers should use **consistent timeouts** (some already use `.timeout` in UI); align defaults so the app never hangs indefinitely on a stuck native backend.

### 7.2 Concurrency, cancellation, and duplicate work

- **Single-flight / in-flight deduplication:** Two screens requesting the same cache key should **share one** generation future (avoid duplicate GPU work).
- **Cancellation:** Long generations should respect **route dispose** or explicit cancel where `flutter_gemma` supports stop generation (Android/Web/Desktop per plugin docs)—at minimum, avoid updating UI after `dispose`.
- **Background isolates:** Keep heavy work off the UI isolate consistent with current patterns (`Isolate.run` today); align with plugin threading expectations.

### 7.3 Performance and resource usage

- **Cold start:** Model load time affects first interaction—measure **first open** after install (asset copy + load).
- **Thermal / battery:** Long runs on GPU may throttle; document **expected** session length for QA.
- **Memory:** Profile on a **minimum-spec** target device after migration; adjust `LlmLimits` / `maxTokens` / backend preference if needed.

### 7.4 Observability and supportability

- **Structured logging:** Log **engine kind**, **model id/version**, **cache hit/miss** (no raw child-generated text in logs in production builds unless strictly necessary and policy-approved).
- **Debug tooling:** Optional dev-only overlay or settings row: last error from install/inference, cache version—reduces “works on my machine” cycles.
- **Analytics hooks (optional):** Aggregate events only (e.g. `generation_failed`, `gate_rejected`, `model_prepare_failed`)—avoid PII and avoid logging prompt bodies.

### 7.5 Security and supply chain

- **Model provenance:** Choose **HTTPS** artifact URLs from trusted hosts; verify checksums where upstream publishes them; compile URLs into builds via **CI secrets** / maintainer `.env` — weights are **not** committed to git.
- **Tokens:** Optional **`IKAMVA_HF_TOKEN`** compile-time define for gated Hugging Face URLs; do not log or expose in learner UI.
- **Dependency review:** `flutter pub outdated` / occasional audit; `flutter_gemma` pulls native code—track **security advisories** for the plugin and its transitive deps.

### 7.6 Privacy, compliance, and store copy

- **On-device inference disclosure:** App Store / Play privacy forms and in-app **About** or onboarding should state that **all AI / LLM inference runs on device**, that **model weights are downloaded once** to the device (first launch / recovery), and that **prompts and model outputs are not sent to your servers for inference** (align wording with any optional non-LLM network features).
- **Child audience:** Pair with existing safety story: **gate** + **no training on user data** (true for local inference) if stated publicly—verify wording with product/legal if the app is positioned for minors.

### 7.7 Localization and accessibility

- **Prompt language:** Generation prompts should specify **target locale** (e.g. UK vs US English) if the product supports variants; avoid ambiguous “English” where spelling matters.
- **Generated content:** Screen readers and dynamic type should remain usable—no assumption that generated strings are always short.

### 7.8 Settings and power-user controls (as needed)

- **Backend preference:** Expose or respect **`PreferredBackend`** (GPU vs CPU) where the plugin allows—useful for debugging and low-end devices.
- **Model management:** Optional “clear model cache” / purge plugin install for support; **first-run** download is the normal path for weights.

### 7.9 Data and migration from pre-Gemma builds

- **Existing caches:** Bump **prefs/DB cache keys** or version fields so users upgrading from stub-heavy builds do not keep **invalid or un-gated** cached blobs.
- **Seed / Drift content:** Plan whether **DB migrations** are required when replacing static copy with generated+cached content (see Phase G in tasks).

### 7.10 CI and release engineering

- **Build matrix:** Ensure **release** iOS/Android still build with new pods and ProGuard rules; add a **stub** job that runs fast tests without native LLM.
- **Artifacts:** If CI cached `native/build`, remove those steps when **`native/`** is deleted.

---

## 8. Out of scope (unless explicitly added)

- Porting **GGUF** weights to MediaPipe/LiteRT formats (use published converted models or official channels; **GGUF is not a supported artifact** after `native/` removal).
- **Embeddings / RAG** via `flutter_gemma` (valuable later; not required to replace `generate`).
- **Remote LLM APIs** (OpenAI, Gemini API, self-hosted inference endpoints, etc.) — **not part of this product**; see **product invariant** at top of document.
- **Remote LLM inference** (third-party APIs) — unchanged; see **product invariant**.

---

## 9. Success criteria

- **`./native` deleted**; no remaining references to `llama-cli`, `IKAMVA_GGUF`, or `IKAMVA_LLAMA_CLI` in shipped code paths (CI may use `IKAMVA_USE_STUB_LLM` or equivalent).
- On a **reference device**, after **one successful HTTPS download** (compile-time URL), real **`LlmService.generate`** flows work **only** through `flutter_gemma`; subsequent launches use on-disk weights without re-download unless recovery runs.
- **Every** production code path that surfaces model output runs **`ChildFriendlyContentGate`** before persistence or UI; failed gate triggers **safe fallback or retry policy** (documented per feature).
- **Caching** prevents redundant generation for stable inputs (verified by code review or light metrics/logging).
- **Prompts** for generation include **explicit output structure** (review `assets/prompts/` and any inline prompt builders).
- **Docs** (README, TASKS, spec) describe **on-device Gemma** only; **Unit/integration tests** without weights still pass.
- **Degraded modes** documented and manually smoke-tested: **airplane mode** after install, corrupt/missing on-disk model (recovery download), gate failure—no silent wrong content for child-facing flows.
- **Cache invalidation** strategy in code (global or per-feature version bumps) verified after model or prompt changes.
- **Release builds** (iOS + Android) pass with plugin native deps; no debug-only assumptions in production paths.
- **No remote inference:** Code review confirms **no** calls to third-party or first-party **LLM inference** HTTP APIs; **`fromNetwork`** is used **only** to fetch **weights** to the device (not for inference); `LlmService` resolves only to **on-device** engines or **test stubs**.

---

## 10. References

- [flutter_gemma on pub.dev](https://pub.dev/packages/flutter_gemma)
- In-repo: `learner_app/lib/llm/`, `learner_app/lib/safety/child_friendly_content_gate.dart`, `learner_app/lib/state/settings_store.dart` (profiles / knobs), `assets/prompts/`, `TASKS.md`
- **Rolling implementation notes:** root [`CHANGELOG.md`](../CHANGELOG.md) (*Unreleased*) and [`README.md`](../README.md) (Models; VS Code, `.env`, and CI) list concrete behaviour (HTTP-only weights, splash probe, prepare screen, purge on corrupt archives, debug panel, timeouts, workflows) kept in sync with this scope.
