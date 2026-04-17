
Ikamva Lam — Advanced Technical Spec

⸻

🎯 1. Design Goals (Aligned to Tracks)

Main Track
	•	End-to-end system (learner app + teacher loop)
	•	Real-world deployable in low-resource schools  ￼

Future of Education
	•	Structured learning, not open chat
	•	Measurable improvement (accuracy, comprehension)

Digital Equity & Inclusivity
	•	Works offline-first
	•	Supports multilingual scaffolding
	•	Runs on low-end hardware

llama.cpp Track
	•	Optimised local inference pipeline
	•	Quantised Gemma 4
	•	Efficient memory + token usage

⸻

🧱 2. System Architecture (Upgraded)

[ Learner Device (Tablet / Low-end Laptop) ]
    |
    |-- UI (Flutter)
    |-- Game Engine
    |-- Local DB (SQLite)
    |-- AI Runtime (llama.cpp + Gemma 4 E2B/E4B)
    |-- Content Cache + Prompt Templates
    |
[ Optional Sync Layer ]
    |
[ Teacher Dashboard (Web) ]


⸻

🎨 2.1 Learner App Interface: Motion, Illustration & Voice

The learner-facing UI is multimodal by design—not only taps and text—to support oral practice, listening comprehension, and sustained engagement.

	•	Animations — transitions, feedback, and micro-interactions that reinforce success, pacing, and attention without overwhelming low-end devices.
	•	Illustrations — narrative and instructional visuals that scaffold meaning, especially for younger learners and lower literacy levels.
	•	Voice (hints & instructions) — spoken guidance layered on reading tasks so learners hear correct pronunciation, intonation, and task framing while they read on screen; supports listening-as-you-read and reduces reliance on dense text alone.
	•	Voice-based commands — optional hands-free / eyes-up flows (e.g. repeat, skip, “read aloud”, answer by speaking) to encourage learners to practice speaking and to stay in a speak–listen loop alongside silent reading.

Together, these modalities aim to: encourage learners to practice speaking aloud, listen actively while reading, and alternate between receptive (listening/reading) and productive (speaking) skills in a single session.

⸻

🤖 3. AI Architecture (CORE DIFFERENTIATOR)

This is where you win the competition.

3.1 Model Selection Strategy

Use Case	Model
Low-end devices	Gemma 4 E2B (2B)
Mid devices	Gemma 4 E4B (4B)
Teacher analytics (optional server)	26B

Why:
	•	Small models are designed for edge/mobile use  ￼
	•	Can run with ~8GB RAM devices  ￼

⸻

3.2 llama.cpp Integration (CRITICAL FOR PRIZE)

Runtime stack

Flutter App
   ↓
FFI Bridge (C bindings)
   ↓
llama.cpp runtime
   ↓
Gemma 4 GGUF (4-bit quantised)


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

Each game maps to:
skill_id + difficulty_level


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

📊 6. Teacher Intelligence Layer

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

6.3 Teacher Dashboard (Optional Cloud)
	•	Sync summaries only (not raw data)
	•	Low bandwidth

⸻

⚡ 7. Performance Engineering (llama.cpp Focus)

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
Fetch from Cache OR Generate via AI
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

For llama.cpp Prize
	•	Real edge AI system
	•	Efficient quantised inference
	•	Practical deployment

⸻

🧠 Final Positioning (Very Important for Kaggle Writeup)

Frame it like this:

“Ikamva Lam is not just an AI app — it is a fully local, teacher-guided learning system designed for real classrooms where connectivity, time, and resources are limited.”
