# Ikamva Lam — Build Task List

<img src="branding/cover.png" alt="Ikamva Lam cover banner" width="1200" style="max-width: 100%; height: auto;" />

![Ikamva Lam logo](branding/logo.png)

Work against this file in order within each phase unless a task notes a dependency. Check boxes as you complete work. **Definition of done** for a task: code merged locally, builds on target platform(s), and any listed acceptance criteria pass.

**Reference docs:** [spec.md](spec.md), [writeup.md](writeup.md), [design.md](design.md).

---

## Conventions

| Label | Meaning |
|--------|---------|
| **P0** | Blocks demo or core loop |
| **P1** | Important for hackathon judging / writeup claims |
| **P2** | Polish or stretch |
| **FFI** | Native `llama.cpp` bridge (Dart ↔ C) |
| **MVP** | Minimum slice for “learner plays cloze offline with hints” |

**Suggested repo layout (adjust if you prefer monorepo):**

```text
/branding/             # logo.svg, logo.png, cover.png, launcher_icon.png
/learner_app/          # Flutter
/teacher_web/          # optional: Flutter web, or React/Vite
/native/               # llama.cpp build scripts + CMake
/docs/                 # optional: move design/spec copies
TASKS.md
spec.md
design.md
writeup.md
```

---

## Phase 0 — Repository & engineering baseline

- [x] **0.1** Create root README with: project pitch, how to run learner app, where the GGUF lives (or download script), device RAM notes. **(P0)**
- [x] **0.2** Add `LICENSE` appropriate to hackathon / team. **(P2)**
- [x] **0.3** Pin toolchain versions: Flutter SDK channel, Dart version, Android NDK / Xcode if building FFI. Document in README. **(P0)**
- [x] **0.4** CI stub (optional): `flutter analyze`, `flutter test` on push. **(P1)**
- [x] **0.5** `.gitignore`: exclude `*.gguf`, build artifacts, `native/build`, local DB files if any committed by mistake. **(P0)**

**Acceptance:** New clone can follow README to open `learner_app` and run on emulator or device.

---

## Phase 1 — Flutter app shell & design system

- [x] **1.1** **Branding:** assets in [branding/](branding/) — [logo.svg](branding/logo.svg), [logo.png](branding/logo.png), [cover.png](branding/cover.png) (1200×630 via [scripts/generate_cover.py](scripts/generate_cover.py)); mirror PNGs in `learner_app/assets/branding/`. Document in [design.md §5.1](design.md). App: `IkamvaLogo`, `IkamvaAppBarTitle`, `IkamvaCoverBanner`. **(P0)**
- [x] **1.2** Create Flutter project `learner_app` (iOS, Android, desktop as needed for demo). **(P0)**
- [x] **1.3** Implement `ThemeData` + `ThemeExtension<IkamvaColors>` (or equivalent) using tokens from [design.md §5.2](design.md). **(P0)**
- [x] **1.4** Typography: **Nunito** + **Source Sans 3** via `google_fonts` in `lib/theme/app_theme.dart` (see [design.md §5.3](design.md)). **(P1)** — *do not switch to bundled `pubspec.yaml` fonts in theme code without updating design + spec in the same commit.*
- [x] **1.5** Build **app router** (e.g. `go_router` or `Navigator2.0`): splash → welcome → home → game shell → session summary → settings. **(P0)** — *no separate splash route; redirect handles first launch.*
- [x] **1.6** Implement **responsive layout** scaffold: single-column primary content, min touch target 48dp; safe area padding. **(P0)**
- [x] **1.7** Add **settings persistence** (`shared_preferences` or SQLite single row): TTS on/off, hint language preference, reduce motion (read from `MediaQuery.disableAnimations` / platform flag). **(P1)** — *reduce motion is user toggle only for now.*
- [x] **1.8** Placeholder screens matching [design.md screen inventory](design.md): Welcome, Hub, Game shell, Session end, Settings — with copy from writeup tone. **(P0)**

**Acceptance:** Cold start navigates through all placeholder routes without errors; theme readable on tablet; **cover + logo on Welcome; logo on primary AppBars**.

---

## Phase 2 — Domain models & local database

Use **SQLite** (`drift` / `sqflite` / `sqlite3` + FFI). Prefer typed queries and migrations.

- [x] **2.1** Define **LearnerProfile**: `id`, `displayName`, `homeLanguageCode` (nullable), `pairedTeacherCode` (nullable), `createdAt`. **(P0)**
- [x] **2.2** Define **Quest** (teacher assignment manifest mirrored locally): `id`, `topic`, `level` (e.g. A1), `maxDifficultyStep`, `sessionTimeLimitSec` OR `maxTasks`, `startsAt`, `endsAt`, `isActive`. **(P0)**
- [x] **2.3** Define **Skill** enum/table: `vocabulary`, `sentence_structure`, `grammar_tense`, `grammar_plural`, `grammar_articles` (align with spec §4.1; adjust names in one place only). **(P0)**
- [x] **2.4** Define **TaskRecord** (generated content instance): `id`, `taskType` (cloze, reorder, match, dialogue_choice), `skillId`, `difficulty`, `topic`, `payloadJson` (structured blob), `source` (cached, generated), `createdAt`. **(P0)**
- [x] **2.5** Define **Attempt**: `id`, `taskId`, `sessionId`, `learnerAnswerJson`, `correct`, `usedHint`, `hintSteps`, `latencyMs`, `timestamp`. **(P0)**
- [x] **2.6** Define **Session**: `id`, `questId` (nullable for practice mode), `startedAt`, `endedAt`, `tasksCompleted`, `accuracy`, `hintRate`. **(P0)**
- [x] **2.7** Define **SyncOutbox**: `id`, `payloadJson` (summary only), `entityType`, `retryCount`, `lastError`. **(P1)**
- [x] **2.8** Implement **DB migrations** v1…vn; ship a **seed** dev profile + sample quest for UI work without AI. **(P0)**
- [x] **2.9** Repository layer: CRUD for profiles, quests, tasks, attempts, sessions — **no UI in repositories**. **(P0)**

**Acceptance:** App launches, loads seed data, repositories unit-testable (at least one `flutter test` per repository or drift test).

---

## Phase 3 — Task types: schemas & validation

All AI output must be **validated** before showing to learners (fail closed → regenerate or use next cached item).

- [x] **3.1** Define Dart classes / `freezed` / `json_serializable` for **Cloze**: `sentence`, `answer`, `options` (3–4 strings), optional `hint_en`, `hint_xh`, `hint_zu`, `hint_af`. **(P0)**
- [x] **3.2** Define payload for **Reorder**: ordered list of tokens or short phrases; correct permutation reference. **(P1)**
- [x] **3.3** Define payload for **Match**: `left[]`, `right[]`, `pairs` map or list. **(P1)**
- [x] **3.4** Define payload for **Dialogue choice**: short context, `question`, `options`, `correctIndex` or `correctId`. **(P1)**
- [x] **3.5** Implement **JSON schema validation** (manual null checks or `json_schema` package): reject empty strings, wrong option count, duplicate options, sentence length policy (spec: prefer &lt;10 words for A1 — enforce per level table). **(P0)**
- [x] **3.6** Central **TaskNormalizer**: map wrong shapes / legacy keys to canonical model; log validation failures for tuning prompts. **(P1)**

**Acceptance:** Invalid JSON from a test string never reaches the game UI; golden tests for valid/invalid samples.

---

## Phase 4 — Game engine orchestration (no AI yet)

- [x] **4.1** **GameCoordinator** service: given `Quest` or practice config, yields a stream/list of `TaskRecord` (initially from DB seed only). **(P0)**
- [x] **4.2** **SessionController**: start/end session, attach `sessionId` to attempts, enforce time limit OR task count from quest. **(P0)**
- [x] **4.3** **RuleBasedEvaluator** per task type: cloze compares normalized string equality or canonical answer id; reorder compares permutation; match compares pairs; dialogue compares selection. **(P0)**
- [x] **4.4** **Retry policy**: max retries per task (e.g. 2); track `hintSteps` and `usedHint`. **(P0)**
- [x] **4.5** Wire **progress UI** in game shell: “Task 3 of 10”, linear progress bar, pause (saves session state). **(P0)**
- [x] **4.6** Post-attempt **local analytics hook**: emit event to analytics service (stub) with skill id + correctness + hint usage. **(P1)**

**Acceptance:** Full session playable with **static** cloze tasks from DB; session summary shows accuracy consistent with attempts.

---

## Phase 5 — Adaptive difficulty engine

Spec §4.2: &gt;80% → harder; &lt;50% → more support.

- [x] **5.1** Define **DifficultyState** per skill or global session: integer step bounded by quest `maxDifficultyStep`. **(P0)**
- [x] **5.2** Implement rolling window (last `N` attempts, e.g. 10) accuracy calculator per active skill. **(P0)**
- [x] **5.3** Implement state machine: increase step, decrease step, enable “hint-first” mode, or repeat same strand — **within teacher caps**. **(P0)**
- [x] **5.4** Persist difficulty state to SQLite so restarts don’t reset unfairly. **(P1)**
- [x] **5.5** Telemetry fields for judging: expose accuracy before/after in session summary (spec §9). **(P1)**

**Acceptance:** Simulated attempts in a unit test drive difficulty up/down predictably.

---

## Phase 6 — llama.cpp + Gemma integration (FFI)

**Core differentiator** — allocate focused time here.

- [x] **6.1** Choose integration strategy: **`dart:ffi`** to bundled `libllama` **or** subprocess to small native CLI **or** platform channel to Kotlin/Swift wrapper. Document tradeoffs in `native/README.md`. **(P0)**
- [x] **6.2** Script **building llama.cpp** for target platforms (macOS dev, Android arm64, Windows if needed); pin commit hash. **(P0)**
- [x] **6.3** Bundle **Gemma 4 GGUF** `Q4_K_M` (E2B for weak devices, E4B for demo machine); document download location & checksum. **(P0)**
- [x] **6.4** Implement **model load once** at app start (or lazy on first AI feature) with clear loading UI; handle OOM gracefully with user message. **(P0)**
- [x] **6.5** Inference API: `generate({required String prompt, int maxTokens, List<int> stopSequences, int contextSize})` returning string or stream. **(P0)**
- [x] **6.6** Apply spec **context limits** (512–1024 tokens) and **max new tokens** (~120); use stop at first complete JSON `}` where applicable. **(P0)**
- [x] **6.7** **Threading:** run inference on background isolate / native thread; never block UI isolate. **(P0)**
- [x] **6.8** **Memory:** reuse context across calls; avoid reload per task; expose `dispose` for shutdown. **(P1)**
- [x] **6.9** Device profile flag: `lowRam` selects E2B + smaller context; `standard` uses E4B. **(P1)**
- [x] **6.10** **Standalone CLI harness** to exercise **llama.cpp / `llama-cli` outside the Flutter app** (e.g. shell script under `native/scripts/` or a tiny Dart/Go CLI): reads `IKAMVA_LLAMA_CLI` + `IKAMVA_GGUF` (or flags), runs one or more fixed prompts (JSON-only smoke), prints stdout and wall time, exits non-zero on OOM/parse failure — usable from CI and local terminals without `flutter run`. Document in `native/README.md`. **(P1)**

**Acceptance:** On demo hardware, a test prompt returns stable output in a few seconds; app remains responsive. Optional: **6.10** passes against the same binary + GGUF the app uses.

---

## Phase 7 — Prompt templates & pedagogical guardrails

Spec §3.3 — **no open chat**; structured tasks only.

- [x] **7.1** Create `prompts/` (assets or constants): one template per `TASK: generate_*` with slots: `LEVEL`, `TOPIC`, `SKILL`, `DIFFICULTY_STEP`. **(P0)**
- [x] **7.2** Enforce **OUTPUT JSON ONLY** in template text; add “if you cannot comply, output `{}`” escape hatch (handle as retry). **(P0)**
- [x] **7.3** Implement **pedagogy rules** in prompt preamble: short sentences for A1, no complex grammar for beginners, curriculum-aligned vocabulary list injection (static file for MVP). **(P1)**
- [x] **7.4** Implement **hint prompt**: given task + wrong answer, return JSON with multilingual keys `hint_en`, `hint_xh`, `hint_zu`, `hint_af` (subset allowed if model weak). **(P0)**
- [x] **7.5** Optional **normalisation prompt** for code-switching learner answers (spec §5.2): map spoken/written mix to canonical English for evaluator — keep **privacy** (on-device). **(P2)**
- [x] **7.6** **Insight prompt** (teacher): input aggregated error stats → JSON `{ issue, pattern, recommendation }` per spec §6.2. **(P1)**

**Acceptance:** Prompts versioned (`prompt_v3` in DB or file name); changing template doesn’t require code changes beyond loading new asset.

---

## Phase 8 — Generation pipeline, caching & pre-generation

Spec §3.3 pre-generation + §8 data flow.

- [x] **8.1** **TaskQueueService**: maintains10–20 upcoming tasks per (topic, level, skill mix) in SQLite; background fill when count &lt; threshold. **(P0)**
- [x] **8.2** **Background worker** using `compute` / isolate / `Workmanager` (Android) where appropriate; respect battery and thermal (pause when app backgrounded if needed). **(P1)**
- [x] **8.3** **Dedup:** hash sentence stem + answer to avoid near-duplicate tasks in the same session. **(P1)**
- [x] **8.4** **Fallback:** if generation fails, dequeue static tasks from bundled pack (offline safety). **(P0)**
- [x] **8.5** Expose **debug panel** (dev only): cache size, last error, tokens/sec, model path. **(P1)**

**Acceptance:** Airplane mode: new session still receives tasks from cache without blocking UI.

---

## Phase 9 — AI hint path & evaluation order

Spec §8: rule-based first, AI hint if needed.

- [x] **9.1** On wrong answer: show **light hint** (e.g. rule: “look at the verb”) if configured before calling model. **(P1)**
- [x] **9.2** On second wrong: call hint prompt; validate JSON; show **HintDrawer** with language tabs per [design.md §6](design.md). **(P0)**
- [x] **9.3** Optional **TTS** for hint text in selected language (Phase 12). **(P1)**
- [x] **9.4** Ensure **no unbounded chat UI**; hints are single-shot per attempt step. **(P0)**

**Acceptance:** Learner never sees raw model rambling; only structured hint fields render.

---

## Phase 10 — Learner UI: micro-games

Implement inside **GameShell** with shared header + bottom actions (Continue, Hint).

- [x] **10.1** **Cloze screen**: sentence with blank, option chips (design §6), correct/wrong micro-animation (&lt;200ms). **(P0)**
- [x] **10.2** **Reorder screen**: drag-and-drop or tap-to-reorder (choose one pattern for low-end); large hit targets. **(P1)**
- [x] **10.3** **Match screen**: two columns, line drawing optional (if heavy, use tap-first-then-tap). **(P1)**
- [x] **10.4** **Dialogue choice**: short dialogue bubbles + choices. **(P1)**
- [x] **10.5** **Illustration slot**: `Image.asset` per topic or generic placeholder art; topic → asset map. **(P1)**
- [x] **10.6** **Session end**: stars/celebration + accuracy, hints used, time; CTA “Back to hub”. **(P0)**

**Acceptance:** All four types navigable in a demo script (even if some still use seeded JSON).

---

## Phase 11 — Local analytics & teacher insights (on-device)

Spec §6.1–6.2.

- [x] **11.1** **WeakSkillsDetector**: aggregate attempts by skill; flag below threshold accuracy over window. **(P1)**
- [x] **11.2** **ErrorClustering** (MVP): bucket by `grammar_tense`, `subject_verb`, etc., using simple rule tags from evaluator (not ML). **(P1)**
- [x] **11.3** **InsightJob**: when session ends or on teacher screen open, run insight prompt with aggregates; store **InsightCard** records locally. **(P1)**
- [x] **11.4** **Export summary JSON** for sync (not raw attempts): totals + top3 weaknesses + last session stats. **(P1)**

**Acceptance:** After ~20 attempts, dashboard/teacher view shows plausible weakness ordering matching injected test data.

---

## Phase 12 — Multimodal: TTS & optional voice commands

Design §2.1, spec §2.1.

- [x] **12.1** Integrate **TTS** (`flutter_tts`): read task instruction + sentence stem; respect settings toggle. **(P1)**
- [x] **12.2** Locale mapping: EN + choose closest available for ZA languages (fallback to EN if engine lacks voice). **(P2)**
- [x] **12.3** **Voice commands** (stretch): `speech_to_text` for “repeat / skip / read aloud / answer A”; map to `GameCoordinator` actions. **(P2)**
- [x] **12.4** **Accessibility**: captions for TTS strings; test with large text scale factor. **(P1)**

**Acceptance:** With TTS on, completing cloze without reading is possible (listen-only smoke test).

---

## Phase 13 — Teacher loop in app (minimum viable)

Before or instead of full web dashboard.

- [x] **13.1** **Teacher mode** gate (PIN or simple password) on shared tablet. **(P1)**
- [x] **13.2** Screens: create/edit **Quest**, set topic + level + limits, generate **pairing code**. **(P1)**
- [x] **13.3** Show **class summary** list (learners on device): accuracy, sessions, hint rate — from local DB. **(P1)**
- [x] **13.4** Show **insight cards** from Phase 11. **(P1)**
- [x] **13.5** **Privacy copy** visible: summaries only (design §7). **(P1)**

**Acceptance:** Teacher can configure a quest without recompiling; learner sees it on hub.

---

## Phase 14 — Optional sync layer & teacher web dashboard

Spec §6.3, design §7.

- [x] **14.1** Define **API contract** for summary sync: POST compressed JSON, auth token, idempotency key. **(P2)**
- [x] **14.2** Implement **outbox flush** when connectivity returns; exponential backoff. **(P2)**
- [x] **14.3** Scaffold **teacher_web** (Flutter Web or other): login, class list, charts, insight cards. **(P2)**
- [x] **14.4** Deploy static demo (Firebase Hosting, GitHub Pages, etc.) for judges. **(P2)**

**Acceptance:** One end-to-end path: learner offline → later online → summary visible in web (can be mocked server for hackathon).

---

## Phase 15 — Performance, profiling & judging metrics

Spec §7, §9.

- [x] **15.1** Benchmark: cold start → model ready time; first token latency; average task generation time. Record in README table. **(P1)**
- [x] **15.2** Profile memory on 4GB vs 8GB targets; document which model fits. **(P1)**
- [x] **15.3** Implement **metrics capture** in app: accuracy trend, sessions/user, hint rate, offline success rate (spec §9). **(P1)**
- [x] **15.4** **Battery / thermal** spot check: 15-min session on real device. **(P2)** — *Procedure in README “Battery / thermal”.*

**Acceptance:** Writeup numbers can be traced to exported CSV or screenshot from debug/stats screen.

---

## Phase 16 — Demo, video & submission

- [x] **16.1** **Scripted demo**: 90s — teacher assigns quest → learner plays 3 tasks (wrong once → hint) → session summary → teacher insight. **(P0)**
- [ ] **16.2** Record **video** with voiceover hitting all tracks: main system, education structure, equity offline, llama.cpp efficiency. **(P0)** — *Human step: cannot be automated here.*
- [x] **16.3** Update [writeup.md](writeup.md) submission links table with repo, demo URL, video URL. **(P0)**
- [x] **16.4** **Kaggle notebook** (if required): summarize architecture + link to code; optional smoke test cells (no huge model in notebook). **(P1)**

**Acceptance:** Submission checklist complete; demo reproducible from README.

---

## Dependency graph (high level)

- **0 → 1 → 2 → 3 → 4 → 10:** Foundation through playable static tasks and game UI.
- **5 (adaptive)** depends on **4** (attempts and session stats).
- **6 (FFI) → 7 (prompts):** Model bridge then templates; both need **2–3** for persistence and validation.
- **8 (cache / pre-gen)** depends on **6–7** and **3**.
- **9 (hints)** depends on **4**, **6–8**.
- **11 (analytics)** depends on **4**; insight JSON optionally **7**.
- **12 (TTS / voice)** depends on **10** surfaces and **9** for hint text.
- **13 (teacher in-app)** depends on **2**, **11**.
- **14 (web / sync)** depends on **11** and **2** (outbox); can be last.
- **15–16** run alongside; **16** assumes **10** and preferably **13** or **14**.


---

## MVP slice (if time is short)

Complete in this order for a credible demo:

1. Phases **0–5** + seeded tasks (no AI).
2. Phase **6** minimal (single platform) + Phase **7** cloze-only + Phase **8** small cache.
3. Phase **9** hints for cloze + Phase **10.1** + **10.6**.
4. Phase **16** demo polish.

Defer: dialogue game, web dashboard, voice commands, cloud sync.

---

## Open decisions log (fill in as you go)

| Decision | Options | Choice | Date |
|----------|---------|--------|------|
| FFI vs subprocess | dart:ffi / CLI / platform channel | Subprocess `llama-cli` first (stub when paths unset); FFI later | 2026-04-17 |
| State management | Riverpod / Bloc / Provider | Inherited `DatabaseScope` + `SettingsScope` + `SettingsStore` listenable | 2026-04-17 |
| Drift vs raw sqflite | | | |
| Desktop target for judges | macOS / Windows / neither | | |

---

*Last updated: aligned with spec.md, writeup.md, design.md. Edit this file as scope changes.*
