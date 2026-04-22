
Ikamva Lam — Advanced Technical Spec

<img src="branding/cover.png" alt="Ikamva Lam cover banner" width="1200" style="max-width: 100%; height: auto;" />

![Ikamva Lam logo](branding/logo.png) · *Vector: [branding/logo.svg](branding/logo.svg)*

⸻

🎯 1. Design Goals (Aligned to Tracks)

Main Track
	•	End-to-end system (learner app + teacher/parent loop)
	•	Real-world deployable in low-resource schools  ￼

Future of Education
	•	Structured learning, not open chat
	•	Measurable improvement (accuracy, comprehension)

Digital Equity & Inclusivity
	•	Works offline-first
	•	Supports multilingual scaffolding
	•	Runs on low-end hardware

On-device Gemma (flutter_gemma)
	•	MediaPipe / LiteRT-LM inference via the `flutter_gemma` plugin
	•	**`.task` weights via HTTPS** at first use (`IKAMVA_MODEL_DOWNLOAD_URL` compile-time); **not** shipped in the APK; plugin **persists** files on device; **re-download** if missing or corrupt (prepare screen or `LlmService` load path)
	•	Efficient memory + token usage (quantised mobile builds); optional **`IKAMVA_HF_TOKEN`** for gated Hugging Face URLs

**1.1 Adult guide (Teacher/Parent).** The adult who assigns quests and reviews summaries may be a **school teacher** or a **parent** (shared classroom tablet or home device). Specs, design, and **user-visible app copy** use **Teacher/Parent** for that role. Schema names such as `paired_teacher_code` remain shorthand for the paired adult unless a future migration renames them.


⸻

🧱 2. System Architecture (Upgraded)

[ Learner Device (Tablet / Low-end Laptop) ]
    |
    |-- UI (Flutter)
    |-- Game Engine
    |-- Local DB (SQLite)
    |-- AI Runtime (flutter_gemma + HTTP-downloaded Gemma `.task`, persisted on device)
    |-- Content Cache + Prompt Templates + Child-friendly gate (on-device)
    |
[ Optional Sync Layer ]
    |
[ Teacher/Parent dashboard (Web) ]


⸻

🎨 2.1 Learner App Interface: Motion, Illustration & Voice

The learner-facing UI is multimodal by design—not only taps and text—to support oral practice, listening comprehension, and sustained engagement.

	•	Animations — transitions, feedback, and micro-interactions that reinforce success, pacing, and attention without overwhelming low-end devices.
	•	Illustrations — narrative and instructional visuals that scaffold meaning, especially for younger learners and lower literacy levels.
	•	Voice (hints & instructions) — spoken guidance layered on reading tasks so learners hear correct pronunciation, intonation, and task framing while they read on screen; supports listening-as-you-read and reduces reliance on dense text alone.
	•	Voice-based commands — optional hands-free / eyes-up flows (e.g. repeat, skip, “read aloud”, answer by speaking) to encourage learners to practice speaking and to stay in a speak–listen loop alongside silent reading.
	•	Typography — **Nunito** for display and headings and **Source Sans 3** for body and UI labels, wired only through the `google_fonts` package in `learner_app/lib/theme/app_theme.dart` (`GoogleFonts.nunito`, `GoogleFonts.sourceSans3`). Do not swap in bundled `pubspec.yaml` font assets or raw `fontFamily` strings in the theme without updating [design.md §5.3](design.md) in the same change.

Together, these modalities aim to: encourage learners to practice speaking aloud, listen actively while reading, and alternate between receptive (listening/reading) and productive (speaking) skills in a single session.

⸻

🤖 3. AI Architecture (CORE DIFFERENTIATOR)

This is where you win the competition.

3.1 Model Selection Strategy

Use Case	Model
Low-end devices	Gemma 4 E2B (2B)
Mid devices	Gemma 4 E4B (4B)
Teacher/Parent-facing analytics (optional server)	26B

Why:
	•	Small models are designed for edge/mobile use  ￼
	•	Can run with ~8GB RAM devices  ￼

⸻

3.2 flutter_gemma integration (on-device inference)

Runtime stack

Flutter App (`LlmService` → `FlutterGemmaLlmEngine`)
   ↓
`flutter_gemma` plugin (Android / iOS)
   ↓
Gemma `.task` on disk (downloaded once via HTTPS from `IKAMVA_MODEL_DOWNLOAD_URL`; not in `assets/` — see `OBTAINING_MODELS.txt`)


⸻

3.3 Optimisation Techniques (Important for judging)

✅ Quantisation
	•	Use Q4_K_M (4-bit) models
	•	Reduces memory to ~2–4GB VRAM / RAM  ￼

⸻

✅ Context Control
	•	Limit context to 512–1024 tokens
	•	Avoid long chat history
	•	Reset per task

⸻

✅ Prompt Templates (Hard Constraints)
Instead of chat:

TASK: generate_cloze
LEVEL: A1
TOPIC: food

OUTPUT JSON ONLY:
{
  "sentence": "...",
  "answer": "...",
  "options": ["...", "...", "..."]
}


⸻

✅ Token Budgeting
	•	Max tokens per response: 120
	•	Use stop tokens (}) to cut generation early
	•	Prevent hallucination + save compute

⸻

✅ Pre-generation Strategy
	•	Generate exercises in background
	•	Cache 10–20 tasks ahead
	•	No waiting during gameplay

⸻

🎮 4. Learning System Design (Future of Education Track)

4.1 Skill Graph (Important upgrade)

Instead of random tasks:

Skills:
- Vocabulary
- Sentence Structure
- Grammar (Tense, Plural, Articles)
- Reading fluency (decode on screen, pace, phrasing)
- Pronunciation & intonation (stress, rhythm, tune; listen–compare–produce)
- Read aloud (speak a displayed line or dialogue turn; optional reference audio)

Each game maps to:
skill_id + difficulty_level

**4.1.1 AI-generated learner content (uniqueness).** Every **question and task payload** shown to a learner in normal play **must be produced by the on-device Gemma pipeline** so sessions stay **unique** and can adapt to level, topic, and prior errors. Items taken from the **pre-generation cache** still satisfy this requirement **only if** they were **written by the model** when the cache was filled. **Fixed static workbook banks** must **not** be the primary source of served questions in production builds (seeded JSON may remain **for automated tests and local UI development** when the model is unavailable).

**4.1.2 Oral reading, pronunciation, intonation & read aloud.** The learning mix **must include** task types that explicitly support **reading on screen**, **correct pronunciation**, **intonation** (statement vs question, emphasis, chunking), and **read aloud** practice (learner speaks while the app listens or self-checks against a reference). These may pair **TTS or recorded reference** clips with **short prompts** (e.g. “Say this like a question”, “Which word is stressed?”, shadowing, repeat-after-model). Prompt templates and validators **must** output structured JSON for these modes (see TASKS Phase 3/7).

**4.1.3 AI-generated practice topics.** **Topic labels** shown on the learner hub (“today’s themes”) **must be produced by the on-device model** in production, then filtered for deduplication, **child-friendly** screening, and policy. A **fixed fallback topic wheel** is **not** a production source; it may exist **only** when dev-seed / offline tooling explicitly allows it (same policy family as §4.1.1; see `LearnerContentPolicy` in the learner app).

**4.1.4 Child-friendly content gate.** All **AI-generated strings** that learners or **Teacher/Parent** surfaces may show — **hub topics**, **task JSON** (every string field in the payload), **multilingual hint** fields, and **Teacher/Parent insight card** fields (`issue`, `pattern`, `recommendation`) — **must pass** an on-device **child-friendly gate** before SQLite persistence or UI. The gate runs **rule-based** screening first (token blocklist, URL/email heuristics, length caps), then a **Gemma JSON sentiment** pass on consolidated text (prompt marker `TASK: child_content_sentiment_check`; tests use a stub that returns deterministic `{"safe":true}`). Outputs that fail either stage are **dropped** and generation is retried or skipped.

⸻

4.2 Adaptive Difficulty Engine

IF accuracy > 80% → increase difficulty
IF accuracy < 50% → repeat with hints


⸻

4.3 Pedagogical AI Rules

Gemma is NOT free to teach anything.

Rules:
	•	Only generate curriculum-aligned sentences
	•	No complex grammar for A1 learners
	•	Prefer short sentences (<10 words)
	•	For **read aloud** and **pronunciation / intonation** tasks, keep **display text short**, age-appropriate, and aligned to the same level rules; avoid opaque phonetic notation unless the template explicitly requires it

⸻

🌍 5. Inclusivity Layer (Digital Equity Track)

5.1 Multilingual Support (KEY DIFFERENTIATOR)

Use Gemma to:
	•	Explain in:
	•	isiXhosa
	•	isiZulu
	•	Afrikaans

Example:

{
  "hint_en": "Think about present tense",
  "hint_xh": "Cinga ngexesha langoku"
}


⸻

5.2 Code-Switching Support
	•	Learner answers in mixed language → AI normalises to English

⸻

5.3 Offline-First Design
	•	100% usable without internet
	•	Sync only when available

⸻

📊 6. Teacher/Parent intelligence layer

6.1 Local Analytics Engine

Runs on-device:
	•	Weak skills detection
	•	Error clustering

⸻

6.2 Insight Generation (AI-assisted)

{
  "issue": "verb agreement",
  "pattern": "misses 's' in present tense",
  "recommendation": "revise subject-verb agreement"
}


⸻

6.3 Teacher/Parent dashboard (optional cloud)
	•	Sync summaries only (not raw data)
	•	Low bandwidth

⸻

⚡ 7. Performance Engineering (on-device Gemma)

Target Device Profile
	•	RAM: 4–8GB
	•	CPU: mid-range mobile / laptop
	•	No GPU required

⸻

Key Optimisations

7.1 CPU Inference Tuning
	•	Threads = number of CPU cores
	•	Batch size tuned for latency

⸻

7.2 Memory Management
	•	Load model once
	•	Reuse context
	•	Avoid reload per request

⸻

7.3 Streaming Output
	•	Show words as they generate
	•	Improves perceived speed

⸻

🔄 8. Data Flow

Game Loop

Start Game
   ↓
Fetch from Cache (AI-filled) OR Generate via AI — **no non-AI question bank in production**
   ↓
User Answer
   ↓
Evaluate (Rule-based first)
   ↓
AI Hint (if needed)
   ↓
Save Result


⸻

🧪 9. Evaluation (FOR JUDGING)

Metrics to show in submission
	•	Accuracy improvement (%)
	•	Sessions per learner
	•	Hint usage rate
	•	Offline success rate

⸻

Demo scenario
	•	1 learner improves from 40% → 70%
	•	Works fully offline
	•	Runs on low-end device

⸻

🚀 10. What Makes This Competitive

For Main Track
	•	Full working system (not just model demo)

For Education
	•	Structured learning + measurable outcomes

For Inclusivity
	•	Works without internet
	•	Multilingual hints

For on-device Gemma / efficiency track
	•	Real edge AI system
	•	Efficient quantised inference
	•	Practical deployment

⸻

🧠 Final Positioning (Very Important for Kaggle Writeup)

Frame it like this:

“Ikamva Lam is not just an AI app — it is a fully local, teacher- or parent-guided learning system designed for real classrooms and homes where connectivity, time, and resources are limited.”
