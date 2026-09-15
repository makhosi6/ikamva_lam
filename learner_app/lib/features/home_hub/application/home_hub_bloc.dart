import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../db/app_database.dart';
import '../../../debug/agent_debug_log.dart';
import '../../../llm/flutter_gemma_llm_engine.dart';
import '../../../llm/llm_service.dart';
import '../../../llm/model_diagnostics.dart';
import '../../../state/settings_store.dart';
import '../domain/hub_payload.dart';
import 'home_hub_event.dart';
import 'home_hub_repository.dart';
import 'home_hub_state.dart';

class HomeHubBloc extends Bloc<HomeHubEvent, HomeHubState> {
  HomeHubBloc({
    required IkamvaDatabase database,
    required SettingsStore settingsStore,
    HomeHubRepository? repository,
  }) : _database = database,
       _settings = settingsStore,
       _repository = repository ?? HomeHubRepository(),
       super(const HomeHubInitial()) {
    on<HomeHubStarted>(_onStarted);
    on<HomeHubReloadRequested>(_onReloadRequested);
    on<HomeHubReturnedFromTopic>(_onReturnedFromTopic);
    on<HomeHubResumeVerifyRequested>(_onResumeVerifyRequested);
  }

  final IkamvaDatabase _database;
  final SettingsStore _settings;
  final HomeHubRepository _repository;

  Future<void> _onStarted(HomeHubStarted event, Emitter<HomeHubState> emit) async {
    var modelWarmSucceeded = false;

    if (shouldUseFlutterGemmaEngine) {
      ModelDiagnostics.instance.log(
        area: 'hub',
        action: 'warm_start',
        message:
            'Warming on-device Gemma (first launch can take a few minutes)…',
      );
      emit(const HomeHubLoading(phase: HomeHubLoadPhase.modelWarm));
      HubPayload? payload;
      try {
        
        // Yield until the loading panel paints once. flutter_gemma's GPU open
        // saturates the OpenCL pipeline; if it starts on the same vsync as the
        // first frame, FlutterSurfaceView/TextureView can lose its buffer queue
        // (BLASTBufferQueue "Already acquired max frames") mid-init and crash.
        // Run warm-up before hub payload. Let the loading panel paint once before
        // LiteRT GPU init (same as engine path — reduces BLAST / buffer-queue issues).
        try {
          if (LlmService.instance.onDeviceWeightsReady.value) {
            ModelDiagnostics.instance.log(
              area: 'hub',
              action: 'warm_skip',
              message:
                  'On-device model already warm — skipping redundant ensureReady.',
            );
            modelWarmSucceeded = true;
            if (!isClosed) {
              ModelDiagnostics.instance.log(
                area: 'hub',
                action: 'warm_ok',
                message: 'Gemma is ready for today\'s topics.',
              );
            }
          } else {
            await SchedulerBinding.instance.endOfFrame;
            // #region agent log
            agentDebugLog(
              location: 'home_hub_bloc.dart:_onStarted',
              message: 'hub warm ensureReady start',
              hypothesisId: 'A',
            );
            // #endregion
            await LlmService.instance.ensureReady();
            // #region agent log
            agentDebugLog(
              location: 'home_hub_bloc.dart:_onStarted',
              message: 'hub warm ensureReady end',
              hypothesisId: 'A',
            );
            // #endregion
            modelWarmSucceeded = true;
            if (!isClosed) {
              ModelDiagnostics.instance.log(
                area: 'hub',
                action: 'warm_ok',
                message: 'Gemma is ready for today\'s topics.',
              );
            }
          }
        } on Object catch (e) {
          if (!isClosed) {
            ModelDiagnostics.instance.log(
              area: 'hub',
              action: 'warm_failed',
              message: 'Could not finish model setup: $e',
              data: <String, Object?>{
                'hint': 'Settings → Warm up model; free storage',
              },
            );
          }
        }
        payload = await _repository
            .loadPayload(_database)
            .timeout(
              const Duration(minutes: 3),
              onTimeout: () => throw TimeoutException('hub_payload'),
            );
        if (isClosed) return;
        if (!isClosed) {
          ModelDiagnostics.instance.log(
            area: 'hub',
            action: 'hub_content_ready',
            message:
                'Daily hub payload resolved; prefs/topics updated for navigation.',
          );
          emit(const HomeHubLoading(phase: HomeHubLoadPhase.fetchingHub));
          emit(HomeHubReady(payload));
        }
      } on Object {
        if (!isClosed) {
          emit(
            const HomeHubFailure(
              'We could not prepare today\'s topics in time. Please retry.',
            ),
          );
        }
      } finally {
        if (shouldUseFlutterGemmaEngine && modelWarmSucceeded) {
          LlmService.instance.releaseInstallUiHooks(_settings);
        }
      }
      return;
    }

    modelWarmSucceeded = true;
    if (isClosed) return;

    emit(const HomeHubLoading(phase: HomeHubLoadPhase.fetchingHub));
    try {
      final payload = await _repository
          .loadPayload(_database)
          .timeout(
            const Duration(minutes: 3),
            onTimeout: () => throw TimeoutException('hub_payload'),
          );
      if (!isClosed) {
        ModelDiagnostics.instance.log(
          area: 'hub',
          action: 'hub_content_ready',
          message:
              'Daily hub payload resolved; prefs/topics updated for navigation.',
        );
        emit(HomeHubReady(payload));
      }
    } on Object {
      if (!isClosed) {
        emit(
          const HomeHubFailure(
            'We could not prepare today\'s topics in time. Please retry.',
          ),
        );
      }
    }
  }

  Future<void> _onReloadRequested(
    HomeHubReloadRequested event,
    Emitter<HomeHubState> emit,
  ) async {
    if (state is HomeHubLoading) return;

    emit(const HomeHubLoading(phase: HomeHubLoadPhase.fetchingHub));
    try {
      final payload = await _repository
          .loadPayload(_database)
          .timeout(
            const Duration(minutes: 3),
            onTimeout: () => throw TimeoutException('hub_payload'),
          );
      if (!isClosed) emit(HomeHubReady(payload));
    } on Object {
      if (!isClosed) {
        emit(
          const HomeHubFailure(
            'We could not prepare today\'s topics in time. Please retry.',
          ),
        );
      }
    }
  }

  Future<void> _onReturnedFromTopic(
    HomeHubReturnedFromTopic event,
    Emitter<HomeHubState> emit,
  ) async {
    await _onReloadRequested(const HomeHubReloadRequested(), emit);
  }

  Future<void> _onResumeVerifyRequested(
    HomeHubResumeVerifyRequested event,
    Emitter<HomeHubState> emit,
  ) async {
    if (!shouldUseFlutterGemmaEngine) return;
    final ready = state;
    if (ready is! HomeHubReady) return;

    final HubPayload payload = ready.payload;
    ModelDiagnostics.instance.log(
      area: 'hub',
      action: 'resume_check',
      message: 'Back on hub — verifying on-device model…',
    );
    emit(ready.copyWith(resumeBusy: true));
    try {
      await LlmService.instance.ensureReady();
      if (!isClosed) {
        ModelDiagnostics.instance.log(
          area: 'hub',
          action: 'resume_ok',
          message: 'Model is ready.',
        );
        emit(HomeHubReady(payload, resumeBusy: false));
      }
    } on Object catch (e) {
      if (!isClosed) {
        ModelDiagnostics.instance.log(
          area: 'hub',
          action: 'resume_failed',
          message: 'Model check failed: $e',
        );
        emit(HomeHubReady(payload, resumeBusy: false));
      }
    }
  }
}
