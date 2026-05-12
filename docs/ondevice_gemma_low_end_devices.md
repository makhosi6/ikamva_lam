# On-device Gemma on constrained hardware

This document explains **why** running Ikamva Lam’s on-device path (`flutter_gemma` / LiteRT-LM) on **low-end phones and tablets** is hard, what failure modes look like in logs, and how the app mitigates them. It also answers whether **“use a different thread”** is an effective lever.

**Audience:** engineers maintaining `learner_app` and anyone triaging Android GPU / memory issues in the field.

---

## 1. Architecture recap (what actually runs where)

| Layer | Where it runs |
|--------|----------------|
| Flutter UI & Dart business logic | Dart **main isolate** (single thread for app Dart code by default). |
| `LlmService.ensureReady()` / `FlutterGemmaLlmEngine` | Dart **await**s plugin method channels; work continues on the isolate’s event loop. |
| Model load, LiteRT session, GPU delegate (OpenCL on Android, Metal on iOS) | **Native code** inside the `flutter_gemma` plugin and LiteRT binaries—typically **worker threads** the plugin owns, not threads you create from Dart. |
| Compositing Flutter frames to the screen | **GPU + SurfaceFlinger** (Android) or Metal-backed layers (iOS), competing for the same device resources as inference when a **GPU** backend is selected. |

So: **“move Gemma to another thread”** in Dart (`compute()`, a second `Isolate`, `Future` on a pool) does **not** move LiteRT off the GPU or free a saturated OpenCL queue. It can still help **pure Dart** work (JSON shaping, large string prep) if that ever becomes CPU-bound on the UI isolate—but the dominant cost here is **native + GPU**, not Dart CPU on the hub warm-up path.

---

## 2. Why “another thread” does not fix the crash we saw

On some chipsets (e.g. **MediaTek** parts that log `iris_x7` / `migl` property probes), the following can happen **at the same time**:

1. Flutter asks the GPU to **composite the next frame** (SurfaceView / BLAST path).
2. LiteRT’s **OpenCL** path holds the GPU long enough for **buffer acquire** to time out.

That produces log lines such as:

- `QUEUE_BUFFER_TIMEOUT` … `fenceName: GPU completion` … high `waitFenceTime`
- `BLASTBufferQueue` … `acquireNextBufferLocked: Can't acquire next buffer. Already acquired max frames`

This is **resource contention on the GPU and the display pipeline**, not “Dart blocked the UI thread.” Spawning another **Dart** isolate does not give LiteRT a second GPU; the OS still schedules one compositor and one heavily loaded GPU.

**Mitigations that *do* address that class of bug:**

- **Android:** Prefer **`RenderMode.texture`** (`TextureView`) so Flutter’s output is not stuck behind the same SurfaceView / BLAST buffer contract that was starving under GPU load (see `MainActivity.kt`).
- **Scheduling:** **`SchedulerBinding.instance.endOfFrame`** before starting `ensureReady()` so the loading UI **paints once** before native warm-up hammers the GPU (see `HomeHubBloc`).
- **Backend:** **`PreferredBackend.cpu`** (via **Low RAM** in settings, or the build-time **`--dart-define=IKAMVA_FORCE_CPU_BACKEND=1`**) avoids sharing the GPU delegate for inference—slower, but much more predictable on weak GPUs.
- **Renderer:** Disable **Impeller (Vulkan)** and fall back to **Skia (OpenGL ES)** by uncommenting the `io.flutter.embedding.android.EnableImpeller=false` meta-data in `AndroidManifest.xml`. Vulkan and the OpenCL delegate often compete for the **same** GPU queue / driver path, so dropping Impeller is the most effective single switch on devices that still time out the BLAST consumer **after** TextureView + sequential warm-up.

> Note: even with `RenderMode.texture`, the **activity window** (`VRI[MainActivity]#0`) still has a BLAST consumer on Android 12+. TextureView removes the *Flutter SurfaceView* contention; it does **not** stop window-level BLAST timeouts when Impeller and OpenCL fight for the GPU.

---

## 3. Challenges on inferior / constrained devices

### 3.1 RAM and process death

Gemma 4 weights and the LiteRT runtime need a large **resident** footprint. On devices with **2–4 GB** total RAM, the OS may:

- Kill background tabs or services aggressively.
- **OOM-kill** your process if two heavy native initializers run together (the codebase already uses a **single-flight** guard on `ensureLoaded` to avoid parallel opens).

**Mitigations in product/engine:**

- **Low RAM profile** reduces context window passed to `getActiveModel` (`maxTokens` / context cap; see `ModelPrepareConfig.contextMaxTokensFor`).
- Prefer the **smaller E2B** variant over **E4B** where possible (`ModelPrepareConfig.estimatedInstallMbFor` reflects the size gap).
- Avoid overlapping **multiple** native model opens (documented in `FlutterGemmaLlmEngine`).

### 3.2 Storage and I/O

Install sizes are **multi‑GB** (see `estimatedInstallMbFor` in `model_prepare_config.dart`). Low-end devices often have:

- Slow **eMMC** → long first open, timeouts if the user expects instant chat.
- **Low free space** → install failures (`enospc`-style errors); the engine maps some of those to `LlmResourceException`.

### 3.3 GPU delegates and drivers

**GPU** inference (OpenCL on Android) is faster when it works but is sensitive to:

- Driver bugs and **vendor-specific** property access (benign `W/libc` “Access denied finding property …” lines are common).
- **Metal** delegate failures on some iOS devices (the codebase detects certain error strings and can fall back or guide the user).

The engine already **retries on CPU** when GPU open fails (`FlutterGemmaLlmEngine._openActiveModel`).

### 3.4 Thermal throttling and “it got slower”

Sustained inference heats the SoC; the kernel **throttles** CPU and GPU clocks. User-visible effect: first response feels fine, later responses drag or hit **timeouts** (`LlmService` uses generation timeouts).

### 3.5 Display / configuration churn

Logs like **`ApplicationInfo updating`** / **assets removed/added** often correlate with **theme or dynamic-color** updates. Any **configuration change** can recreate surfaces while the model is warming, which **amplifies** GPU buffer-queue issues. The TextureView + first-frame yield reduce the window where that overlap is fatal.

### 3.5a Hub startup: do not overlap payload LLM with first GPU open

`HomeHubRepository.loadPayload` pulls `DailyTopicsService.loadOffersForToday()`, which may call `LlmService.generate` (topic JSON) and `ChildFriendlyContentGate.evaluateHubTopicsBatchSentiment` (cached topics). Those share `ensureLoaded` / the same native session, but **scheduling them in parallel with the first `ensureReady`** still piles **Impeller (Vulkan) frame work** and **OpenCL delegate compilation** onto the same weak GPU.

On MediaTek-class devices this shows up as **`QUEUE_BUFFER_TIMEOUT`** on **`VRI[MainActivity]#0 (BLAST Consumer)`** (the activity window still uses BLAST even with `RenderMode.texture`), **`Skipped N frames`**, then **`Lost connection to device`** (often OOM or native GPU teardown).

**Mitigation:** On the `flutter_gemma` path, the hub **sequentially** awaits `ensureReady()` before `loadPayload()` so the first OpenCL graph build is not competing with hub topic generation and extra sentiment passes.

### 3.6 Network (HF path)

If the build installs **from network** (Hugging Face), low-end devices add:

- Unstable Wi‑Fi → partial downloads → corrupt or unreadable archives (handled with purge/reinstall paths and user-facing errors).

---

## 4. Operational checklist for field issues

1. **Enable Low RAM** on the device and retry (CPU backend + smaller context).
2. **Use E2B** instead of E4B if the device is storage- or RAM-limited.
3. Capture **`adb logcat`** around hub load: look for `BLASTBufferQueue`, `QUEUE_BUFFER_TIMEOUT`, `Lost connection to device`, and `DEBUG`/`ERROR` from `flutter` / `tflite` / `litert`.
4. Confirm **free disk** above `ModelPrepareConfig.minFreeDiskMb` (and headroom) before blaming “bad model.”
5. After changing **Android embedding** (`RenderMode`), do a **clean rebuild**; hot reload does not apply Kotlin changes.
6. If `QUEUE_BUFFER_TIMEOUT` on `VRI[MainActivity]#0(BLAST Consumer)` persists after the above, escalate in this order:
   a. Build with **`--dart-define=IKAMVA_FORCE_CPU_BACKEND=1`** (forces LiteRT CPU delegate regardless of Low RAM).
   b. Uncomment the **`EnableImpeller=false`** meta-data in `AndroidManifest.xml` to fall back to **Skia / OpenGL ES**.
   c. Re-run; if the device still dies, the GPU/driver simply cannot host LiteRT + Flutter rendering at the same time — keep that build flag set for that SoC family.

---

## 5. Future threading work (when it is worth it)

| Idea | Value on low-end devices |
|------|---------------------------|
| Dart **isolate** for prompt building / JSON post-processing | Medium, if profiling shows UI jank from Dart CPU only. |
| “Run `ensureReady` on a background isolate” | **Low** for LiteRT: the heavy lifting is native; isolates cannot share handles into the plugin’s model without redesign. |
| Throttle **frame rate** or defer **animations** during warm-up | Medium—reduces GPU load alongside inference. |
| **Plugin-level** native queue (serialize GPU + GL) | High, but requires changes **upstream** in `flutter_gemma` / LiteRT, not app-only. |

---

## 6. Related code (repo map)

| Concern | Location |
|---------|-----------|
| Engine open, GPU→CPU retry, single-flight load | `learner_app/lib/llm/flutter_gemma_llm_engine.dart` |
| Service timeouts, cache invalidation | `learner_app/lib/llm/llm_service.dart` |
| Context / disk constants | `learner_app/lib/llm/model_prepare_config.dart` |
| Hub warm-up (first-frame yield + **sequential** `ensureReady` → `loadPayload` on Gemma) | `learner_app/lib/features/home_hub/application/home_hub_bloc.dart` |
| Android render surface (TextureView) | `learner_app/android/app/src/main/kotlin/.../MainActivity.kt` |
| Model delivery options (asset vs network) | `learner_app/docs/model_delivery.md` |

---

## 7. Revision history

| Date | Change |
|------|--------|
| 2026-05-10 | Add `IKAMVA_FORCE_CPU_BACKEND` build flag and Impeller-disable manifest opt-out for residual `VRI[MainActivity]` BLAST timeouts. |
| 2026-05-10 | Hub: serialize `ensureReady` before `loadPayload` on Gemma path (weak-GPU stability). |
| 2026-05-10 | Initial document: GPU vs threading, low-end constraints, mitigations (TextureView, `endOfFrame`, Low RAM / CPU). |
