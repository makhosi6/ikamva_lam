# Ikamva Lam (“My Future”)

<img src="branding/cover.png" alt="Ikamva Lam cover banner" width="1200" style="max-width: 100%; height: auto;" />

![Ikamva Lam logo](branding/logo.png) · *Vector: [branding/logo.svg](branding/logo.svg)*

Playful English practice for primary and secondary learners—guided by a **Teacher/Parent** (school or home) and powered by on-device Gemma 4

---

## 🧠 Overview

Ikamva Lam is a lightweight learning app that helps learners build English confidence through short, engaging micro-games. It is designed for primary and early secondary learners, especially in environments where:

- English is not the home language
- Access to books and devices is limited
- Internet connectivity is unreliable

The system keeps the **Teacher/Parent** in control, while AI runs locally on-device to support learners with hints, feedback, and structured practice. The learner app is deliberately multimodal—animations, illustrations, and voice—so learners can listen while they read, practice speaking aloud, and use optional voice commands without everything depending on dense on-screen text alone.

**One-line pitch:** Ikamva Lam builds English confidence through guided play, with Teacher/Parent oversight, a rich multimodal learner interface, and fully offline AI support.

---

## ❗ Problem

South Africa faces a well-documented literacy challenge:

- Many learners struggle with reading for meaning, especially by Grade 4
- English is often introduced before learners are fully literate in their home language
- Classrooms are multilingual and resource-constrained

In practice:

- Learners don’t get enough repetition and feedback
- Teachers and parents often lack time for individual attention at scale
- Digital tools often depend on internet access, which is unreliable or expensive

---

## 💡 Solution

Ikamva Lam focuses on structured, engaging repetition through gameplay.

### 🎮 Micro-Games

Learners complete short activities like:

- Fill-in-the-blank (cloze)
- Sentence reordering
- Vocabulary matching
- Dialogue choices

These are designed to be:

- Short (1–3 minutes)
- Repeatable
- Context-based (not just drills)

Activities map to a simple skill graph (vocabulary, sentence structure, grammar) with a difficulty level, so practice is structured rather than random. An adaptive layer raises difficulty when accuracy stays high and offers more support (including hints) when learners struggle.

---

## 🎨 Motion, illustration & voice

The interface uses motion, art, and audio together to support literacy and oral confidence:

- **Animations** — clear feedback, pacing, and reward cues tuned so low-end devices stay responsive.
- **Illustrations** — meaning-making visuals that scaffold tasks for younger learners and lower reading levels.
- **Spoken hints and instructions** — learners hear pronunciation, intonation, and task framing while reading on screen, strengthening listen-as-you-read habits.
- **Voice-based commands** — optional flows (e.g. repeat, skip, read-aloud, answer by speaking) that encourage speaking practice and keep learners in a speak–listen loop alongside reading.

---

## 👩🏽‍🏫 Teacher/Parent in the loop

The adult guide may be a **school teacher** or a **parent**—the same product flows apply. **Teacher/Parent**:

- Sets topics (e.g. food, school, daily life)
- Chooses difficulty levels
- Controls time or session limits

They also receive:

- Summaries of learner performance
- Common mistakes, weak skills, and clustered error patterns (computed on-device where possible)
- Optional AI-assisted insights (e.g. recurring issues and revision suggestions)

An optional **Teacher/Parent** web dashboard can sync low-bandwidth summaries—not raw learner dialogues—when connectivity allows.

This allows teachers and parents to:

- Adjust lessons or home practice
- Run small-group interventions or one-to-one support
- Stay fully in control of learning outcomes

---

## 🤖 On-Device AI (Gemma 4)

The key innovation is using Gemma 4 locally, not in the cloud.

We run inference with **`flutter_gemma`** (MediaPipe / LiteRT-LM) so Gemma stays **fully on-device** on phones and tablets—no cloud LLM, no runtime download of weights. Bundled `.task` models and a **Low RAM** profile keep the experience usable on modest hardware.

This enables:

- ✅ Offline or low-data usage
- ✅ Better privacy (no learner data sent externally)
- ✅ Deployment in low-resource schools

The AI handles:

- Generating practice questions
- Giving hints (including multilingual explanations where configured)
- Rephrasing incorrect answers
- Adapting difficulty within Teacher/Parent-defined limits

Generation stays bounded: short outputs, tight token budgets, curriculum-aligned wording (e.g. simpler sentences for early levels). Tasks can be pre-generated in the background and cached so gameplay rarely waits on the model.

---

## ⚙️ Technical Approach

- Flutter learner client (tablet / low-end laptop friendly) with a lightweight game layer
- Local persistence (e.g. SQLite) for progress, cache, and templates
- On-device inference via `flutter_gemma` + quantised Gemma `.task` downloaded over HTTPS once per device (smaller builds on the weakest devices, larger where storage/RAM allows)
- Structured prompting (not open chat), focused on:
  - Game generation
  - Hint generation
  - Controlled outputs (JSON-like formats)

**Design principles:**

- Keep AI bounded and predictable
- Avoid “free chat” — focus on learning tasks
- Ensure outputs are curriculum-aligned and safe

---

## 🔁 Example Workflow

1. Teacher/Parent assigns a weekly quest (topic + difficulty)
2. Learners complete short game sessions—tasks are served from cache or generated on-device as needed
3. Answers are evaluated with rules first; the model supplies hints when appropriate, including spoken guidance where enabled
4. Results and skill signals are stored locally for analytics
5. Teacher/Parent reviews summary (and optional insight cards) and adjusts support or teaching

---

## 🌍 Why This Matters

Ikamva Lam is built for real classroom conditions, not ideal ones.

It directly addresses:

- Limited connectivity
- Shared devices
- Adult (teacher/parent) workload
- Need for engaging literacy practice
- Multilingual classrooms—scaffolding and hints can be offered in languages such as isiXhosa, isiZulu, and Afrikaans alongside English, with support for mixed-language learner responses normalised for assessment

Instead of replacing teachers or parents, it amplifies their reach.

---

## 🚀 What Makes This Different

- Offline-first AI learning tool
- Teacher/Parent-controlled AI (not autonomous)
- Skill-linked games plus adaptive difficulty—not undifferentiated drills
- Multimodal learner experience: animation, illustration, and voice (listening, speaking, optional voice commands)
- Focus on practice volume + motivation
- Designed specifically for multilingual classrooms (with explicit local-language scaffolding)

---

## 🔗 Submission Links

**Repository release:** learner app `0.6.0+1` (`learner_app/pubspec.yaml` and `lib/version.dart`).

| Asset | URL |
| ----- | --- |
| Code  | *(add public Git remote URL when published)* |
| Demo  | *(add GitHub Pages / Firebase Hosting URL after deploy — see README “Deploy demo”)* |
| Video | *(record per `DEMO.md`; agent cannot produce the final video file)* |

---

## 📚 References

- Gemma 4 Good Hackathon (Kaggle)
- Research on South Africa’s reading crisis
- Literacy engagement and motivation studies (UWC)

---

## 🧩 Future Work

- Deeper longitudinal models of mastery per skill over terms and years
- Richer speech feedback (pronunciation scoring, more voice locales)
- Expanded Teacher/Parent dashboard exports and class- or household-level rollups
- Further optimisation for the lowest RAM tiers without sacrificing multimodal UX

---
