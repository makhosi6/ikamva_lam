# Task breakdown: `flutter_gemma` as primary AI engine

Companion to [flutter_gemma_migration_scope.md](./flutter_gemma_migration_scope.md).  
Execute in order where dependencies apply; parallelize platform spikes where marked.

**Branch mandates (see scope):** remove **`./native`**, **on-device Gemma** as the **only** inference path (**no server-side or cloud LLM**), **model weights via HTTPS** (`IKAMVA_MODEL_DOWNLOAD_URL`, persisted on device — **not** in the APK), **`ChildFriendlyContentGate` on every generated surface**, **caching** to avoid repeat inference, and **structured prompts** for all generation tasks.

### Implementation status (2026-04-20)

Legend: **Done** = merged in this repo pass · **Partial** = started / docs only / follow-up · **Later** = not in this milestone.

| Status | IDs |
|--------|-----|
| **Done** | **A.1–A.4**, **A.9** (README device section), **B.1**, **B.2** (Podfile + Info.plist deltas), **B.3**, **B.6**, **B.7** (README + `OBTAINING_MODELS.txt`), **C.1–C.6** (incl. streaming on `FlutterGemmaLlmEngine`), **D.2**, **D.3**, **E.1**, **E.3**, **F.1–F.4**, **H.1** (service timeouts), **H.2** / **H.3** (actionable errors; storage message in engine), **I.2** (Teacher privacy copy), **I.3** (README provenance), **J.1** (UK English line in `pedagogy_preamble.txt`), **J.2** (`hub_daily_topics_v4`), **J.4** (README upgrade steps) |
| **Partial** | **A.5–A.8** (policy/gate/cache matrix not fully tabulated in docs), **A.10** (analytics events not wired), **D.1** (progress callback on `configure`; no determinate UI bar yet), **E.2** (device smoke — manual), **E.5** (matrix below), **H.6** (benchmark table still TBD), **I.1** / **I.5** (light review; no formal sign-off doc), **J.3** (CI had no `native/` build steps; job unchanged) |
| **Later / out of scope** | **B.4** Web, **B.5** Desktop, **E.4** golden prompts, **H.4** single-flight, **H.5** cancel-on-dispose, **I.4** debug last-error row, **G.\*** |

> **Rolling doc:** the repository root [`CHANGELOG.md`](../CHANGELOG.md) section **Unreleased** is the canonical checklist of implementation + documentation updates (HTTP-only model, `.env` / VS Code / CI, splash & prepare flows, engine recovery, UI fixes, etc.). This task file’s tables above are aligned where noted; minor wording may still say “bundle” in historical rows — prefer **CHANGELOG** for “what shipped”.

**Manual QA matrix (E.5)** — expected UX:

1. **Airplane mode after first successful download:** inference still works (model on disk); no new download until recovery.  
2. **Missing URL or corrupt install:** `ensureReady` / warm-up shows clear error; on mobile fix URL or re-download from prepare screen; stub only when host is non-mobile or `IKAMVA_USE_STUB_LLM=1`.  
3. **Low storage on first download:** user sees storage-related error string from engine path.  
4. **Gate fail after generation:** existing per-feature retry / safe empty behavior (verify hub + task queue paths manually).

---

## Phase A — Product and model decisions

| ID | Task | Output / done when |
|----|------|---------------------|
| A.1 | Pick **default inference model** (size, `ModelType`, file format) balancing **quality vs download size**; record **HTTPS artifact URL** (`IKAMVA_MODEL_DOWNLOAD_URL`) and optional gated-repo token story. | Documented in `OBTAINING_MODELS.txt` + README; URL compile-time only. |
| A.2 | **No APK weights:** do **not** declare `.task` under **`pubspec.yaml` `assets`**; ship only docs (`OBTAINING_MODELS.txt`). APK stays small; first run downloads. | `flutter build` succeeds without weight assets; production uses **`fromNetwork`**. |
| A.3 | Confirm **target platforms** for this milestone (Android + iOS minimum; web/desktop yes/no). | List in scope ticket. |
| A.4 | **Remove `ProcessLlmEngine` / `llama-cli` / GGUF** from the app: production uses **`FlutterGemmaLlmEngine`** only; **`StubLlmEngine`** for tests/CI via `IKAMVA_USE_STUB_LLM` (or test doubles). | `LlmService._createEngine` documents precedence; no production path references `native/build`. |
| A.5 | List **exceptions** to “all content from Gemma” (UI chrome, legal, fixed IDs, etc.); everything else planned as **generate → gate → cache → show**. | Short table in scope or ADR. |
| A.6 | **Cache matrix:** for each `LlmService` consumer, define key, TTL/version invalidation, behavior when gate fails (retry once, fallback string, empty state). | Table in scope or wiki; implemented in code. |
| A.7 | **Prompt audit:** ensure each generator prompt states **JSON shape / fields / example** (and “JSON only, no markdown” where used). | `assets/prompts/` and inline builders reviewed; gaps filed as tasks. |
| A.8 | **Gate audit:** trace every path that shows learner-facing model text; ensure **`ChildFriendlyContentGate`** (rules + sentiment when required) runs **before** persist/display. | Checklist complete; tests for regressions. |
| A.9 | Define **minimum device profile** (RAM, OS) for the chosen model; document “unsupported / best effort” if below. | README + optional runtime warning. |
| A.10 | Decide **analytics** (if any): only aggregate technical events (`model_prepare_failed`, `inference_error`, `gate_reject`); **no** prompt bodies or child text. | Event list + privacy note. |

---

## Phase B — Dependency and project wiring

| ID | Task | Output / done when |
|----|------|---------------------|
| B.1 | Add `flutter_gemma` to `learner_app/pubspec.yaml` with **pinned** version; run `flutter pub get`. | Clean resolve, lockfile if used. |
| B.2 | **iOS:** Verify `Podfile` vs plugin (platform `16.0`, `use_frameworks! :linkage => :static`); add any missing **Info.plist** / **entitlements** from [flutter_gemma](https://pub.dev/packages/flutter_gemma) setup for large models and file sharing. | `pod install` succeeds; document deltas. |
| B.3 | **Android:** Add **OpenCL** `uses-native-library` entries if using GPU; confirm **ProGuard** if release fails. | Release build note or config committed. |
| B.4 | **Web (if in scope):** Add **MediaPipe / plugin** script tags to `web/index.html`; set `WebStorageMode` if large models. | `flutter run -d chrome` smoke with plugin init only. |
| B.5 | **Desktop (if in scope):** macOS `setup_desktop.sh` build phase, entitlements; Windows/Linux deps per readme. | Build passes on one desktop target. |
| B.6 | Add **`FlutterGemma.initialize`** in `main.dart` with optional **`huggingFaceToken`** from compile-time **`IKAMVA_HF_TOKEN`** when URLs are gated. | `main.dart` matches plugin + gated-download needs. |
| B.7 | **Secrets / defines:** document **`.env`**, **`--dart-define-from-file`**, VS Code **`launch.json`**, and GitHub **`secrets.IKAMVA_MODEL_DOWNLOAD_URL`** / **`IKAMVA_HF_TOKEN`** for release builds — not git-stored binaries. | README + workflow + `.env.example`. |

---

## Phase C — Engine implementation

| ID | Task | Output / done when |
|----|------|---------------------|
| C.1 | Create **`FlutterGemmaLlmEngine`**: production uses **`installModel`…`fromNetwork`** (`IKAMVA_MODEL_DOWNLOAD_URL`); then `getActiveModel`, **`createSession`** per `generate`; re-download if active model missing; map `maxTokens` / context from `LlmGenerateRequest` and `LlmLimits`. | Class compiles; **no** bundled weights in APK. |
| C.2 | Reuse **`LlmOutputFilters.takeThroughFirstBalancedJson`** (and stop-sequence loop) so JSON consumers unchanged. | Parity with `ProcessLlmEngine` post-process behavior. |
| C.3 | Wire **`dispose`** to close plugin model/session to avoid leaks; align with **`invalidateCachedEngine`**. | No double-close errors; settings refresh still works. |
| C.4 | Update **`LlmService._createEngine()`**: **Flutter Gemma** when model ready; **stub** for CI/dev flag only; **delete `ProcessLlmEngine`** and related env (`IKAMVA_GGUF`, `IKAMVA_LLAMA_CLI`) from production logic. | Precedence table in code comment; grep clean. |
| C.5 | **(Optional same milestone)** Implement **`StreamingLlmCapability`** using `generateChatResponseAsync` + token/chunk mapping to `Stream<String>`. | `tryOpenGenerateStream` non-null when engine supports it. |
| C.6 | Remove **`process_llm_engine.dart`**, **`runLlamaCliSync`**, and tests/docs that only exist for the subprocess path; adjust imports. | No `llama-cli` / GGUF references in `learner_app/lib`. |

---

## Phase D — UX and settings

| ID | Task | Output / done when |
|----|------|---------------------|
| D.1 | **First-run “prepare model” UX:** HTTP download with **progress %**, cancel token, storage check, errors (including corrupt archive purge + retry). | `model_prepare_screen.dart` + prefs. |
| D.2 | **`ensureReady`** / **`generate`** await **`ensureLoaded`** (open or re-download) with long timeout (**600s** in `LlmService` for big files). | Timeouts / error strings reviewed. |
| D.3 | Document **compile-time URL** + HF token for maintainers (`OBTAINING_MODELS.txt`, README, CHANGELOG). | Maintainer onboarding matches repo. |

---

## Phase E — Testing and quality

| ID | Task | Output / done when |
|----|------|---------------------|
| E.1 | Update **`llm_service_test.dart`**: with stub/flag, behavior unchanged; add **mocked** or **fakes** if needed to avoid loading real weights in CI. | Tests green in CI. |
| E.2 | **Device smoke:** one end-to-end path (e.g. hint or content gate) on Android and iOS with real model. | Checklist in PR. |
| E.3 | **Regression:** run existing tests for services that call `LlmService` (analytics, game, etc.) with stub. | All pass. |
| E.4 | **Golden / snapshot prompts (optional):** small fixture set of prompts + expected JSON shapes for parsers (no real weights—stub returns fixed strings). | Guards against accidental prompt regressions. |
| E.5 | **Manual QA matrix:** airplane mode after install, missing/corrupt asset, low storage on first prepare, gate fail after generation—document expected UX per flow. | Checklist attached to PR or test plan doc. |

---

## Phase H — Resilience, concurrency, and performance

| ID | Task | Output / done when |
|----|------|---------------------|
| H.1 | **Timeouts:** align defaults across call sites for **inference**; document max wait. | No indefinite hangs; user-visible feedback. |
| H.2 | **Degraded UX:** error states when **download / open** fails (zip archive, missing URL, etc.); purge + actionable copy. | Prepare screen + engine exceptions. |
| H.3 | **Storage:** catch plugin errors if device full during **download**; user-facing message. | Engine maps ENOSPC-style errors to resource message. |
| H.4 | **Single-flight / dedupe:** same cache key in flight → one generation (optional but recommended for hub-sized features). | Code or small helper; no duplicate GPU jobs for identical request. |
| H.5 | **Lifecycle:** cancel or ignore results when widget/route disposed during generation; use `Stop`/plugin cancel where supported. | No UI updates after dispose. |
| H.6 | **Performance smoke:** cold start + one representative generation on **reference** and **low-end** device; tune `maxTokens` / backend if needed. | Notes in PR; `LlmLimits` updated if justified. |

---

## Phase I — Privacy, security, and observability

| ID | Task | Output / done when |
|----|------|---------------------|
| I.1 | **Logging:** structured logs for engine state, cache hit/miss, errors; **redact** learner-generated text in release builds unless explicitly approved. | Code review checklist. |
| I.2 | **Disclosures:** App Store / Play privacy + in-app **About** — **weights downloaded once to device**; **all LLM inference on-device**; prompts/outputs **not** sent for server-side inference; optional non-LLM network called out only if true. | Copy reviewed vs `spec` / README. |
| I.3 | **Provenance:** document **HTTPS URL choice**, CI secrets, checksums if upstream publishes them; compile-time defines **are** the shipped “pointer” to weights (not the bytes). | `OBTAINING_MODELS.txt` + README. |
| I.4 | **Debug settings (optional):** dev-only last error / cache version for support. | Gated behind `kDebugMode` or flavor. |
| I.5 | **Architecture audit:** confirm **no** remote **LLM / chat-completion** APIs; **`fromNetwork`** is **only** for **weight bytes** to device, not inference; generation is **`LlmService` → on-device** (or test stub). | Documented sign-off or PR checklist. |

---

## Phase J — Localization, upgrades, and CI

| ID | Task | Output / done when |
|----|------|---------------------|
| J.1 | **Prompt locale:** generation prompts specify **English variant** (e.g. UK vs US) and any future locale strategy. | Prompts updated; product sign-off. |
| J.2 | **Upgrade path:** bump **SharedPreferences / cache version** keys so old cached content is not reused ungated or from wrong model era. | Migration tested install-over-install. |
| J.3 | **CI workflows:** delete steps that build or cache **`native/`**; ensure **stub** test job remains fast and required. | Green CI on PR. |
| J.4 | **Dependency policy:** pin `flutter_gemma` version; document how to upgrade (run pod install, re-read plugin changelog). | CONTRIBUTING or README subsection. |

---

## Phase F — Documentation and cleanup

| ID | Task | Output / done when |
|----|------|---------------------|
| F.1 | Update **root `README.md`**: **HTTP-downloaded** on-device Gemma via `flutter_gemma`; **`.env` / CI** defines; **remove** `llama-cli` / GGUF / bundled-weight story. | Onboarding matches new engine. |
| F.2 | **Delete `./native`** (scripts, refs, `LLAMA_CPP_REF`, smoke harness tied to subprocess). Update **`.gitignore`** only if entries referenced `native/` artifacts uniquely. | Directory gone; `git grep native` only hits intentional strings (e.g. “native code” in Flutter sense) or is clean. |
| F.3 | Update **`TASKS.md`**, **`spec.md`**, **`writeup.md`**, **`CHANGELOG.md`**, CI/workflow, **`notebooks/`**, and **`learner_app/README.md`** for **`native/`** removal + **HTTP-only** weights + probe/prepare behaviour. | Docs consistent with scope + CHANGELOG *Unreleased*. |
| F.4 | **CHANGELOG** or release notes entry for the migration (if project keeps one). | User-visible summary. |

---

## Phase G — Optional follow-ups (post-merge)

- Adopt **embeddings / RAG** from `flutter_gemma` for features that need retrieval.
- Deeper **seed DB** migration: replace large static narrative blobs with **cached Gemma output** where product wants zero hand-authored lesson text.

---

## Suggested implementation order

1. A.* → B.1–B.2 (mobile core)  
2. C.1–C.4 (engine + `LlmService` selection) + **remove `ProcessLlmEngine`**  
3. A.6–A.8 (cache, prompts, gate) in parallel with feature touch-ups  
4. **H.1–H.3** early (timeouts, degraded UX, storage)—parallel with D.*  
5. D.1–D.2 (prepare-model UX, ensureReady)  
6. **H.4–H.6**, **I.*** , **J.*** interleaved as the integration stabilizes  
7. E.* (tests + QA matrix **E.5**)  
8. **F.2–F.3** (`native/` deletion + doc scrub) before merge  
9. B.3+ / C.5 / F.4 / **J.3–J.4** as capacity allows  

---

## Estimation note

Rough T-shirt sizes: **A** (small–medium), **B** (medium; +1 if web+desktop or LFS setup), **C** (medium–large), **D** (small–medium), **E** (medium), **F** (small–medium), **H** (medium), **I** (small–medium), **J** (small).
