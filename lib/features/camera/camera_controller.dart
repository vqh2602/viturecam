import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../platform/beauty_native_api.dart';
import '../background/background_settings.dart';
import '../beauty/beauty_settings.dart';
import '../color/color_settings.dart';
import '../makeup/makeup_settings.dart';
import '../presets/preset_model.dart';
import '../presets/preset_storage.dart';
import '../reshape/reshape_settings.dart';

class CameraState {
  final List<CameraDevice> cameras;
  final CameraDevice? selectedCamera;
  final int? textureId;
  final bool isStreaming;
  final String resolution; // '1920x1080', '1280x720'
  final int fps; // 30, 60
  final bool mirrorPreview;
  final bool mirrorOutput;
  final bool virtualCameraActive;
  final bool beautyEnabled;
  final String compareMode; // 'none', 'split', 'raw'
  final double splitRatio; // 0.0 .. 1.0
  final String activeCategory; // 'beauty', 'reshape', 'makeup', 'filter', 'color', 'background', 'presets'
  final String activeSubTool;

  final BeautySettings beauty;
  final FaceSettings face;
  final MakeupSettings makeup;
  final String filterId;
  final double filterIntensity;
  final ColorSettings color;
  final BackgroundSettings background;

  final List<PresetModel> presets;
  final String? activePresetId;
  final PerformanceStats stats;
  final bool isLoading;
  final String? errorMessage;

  const CameraState({
    this.cameras = const [],
    this.selectedCamera,
    this.textureId,
    this.isStreaming = false,
    this.resolution = '1920x1080',
    this.fps = 30,
    this.mirrorPreview = true,
    this.mirrorOutput = false,
    this.virtualCameraActive = false,
    this.beautyEnabled = true,
    this.compareMode = 'none',
    this.splitRatio = 0.5,
    this.activeCategory = 'beauty',
    this.activeSubTool = 'smooth',
    this.beauty = const BeautySettings(),
    this.face = const ReshapeSettings(),
    this.makeup = const MakeupSettings(),
    this.filterId = 'original',
    this.filterIntensity = 80,
    this.color = const ColorSettings(),
    this.background = const BackgroundSettings(),
    this.presets = const [],
    this.activePresetId,
    this.stats = const PerformanceStats(fps: 0, renderTimeMs: 0, droppedFrames: 0, width: 1920, height: 1080),
    this.isLoading = false,
    this.errorMessage,
  });

  CameraState copyWith({
    List<CameraDevice>? cameras,
    CameraDevice? selectedCamera,
    int? textureId,
    bool? isStreaming,
    String? resolution,
    int? fps,
    bool? mirrorPreview,
    bool? mirrorOutput,
    bool? virtualCameraActive,
    bool? beautyEnabled,
    String? compareMode,
    double? splitRatio,
    String? activeCategory,
    String? activeSubTool,
    BeautySettings? beauty,
    FaceSettings? face,
    MakeupSettings? makeup,
    String? filterId,
    double? filterIntensity,
    ColorSettings? color,
    BackgroundSettings? background,
    List<PresetModel>? presets,
    String? activePresetId,
    PerformanceStats? stats,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CameraState(
      cameras: cameras ?? this.cameras,
      selectedCamera: selectedCamera ?? this.selectedCamera,
      textureId: textureId ?? this.textureId,
      isStreaming: isStreaming ?? this.isStreaming,
      resolution: resolution ?? this.resolution,
      fps: fps ?? this.fps,
      mirrorPreview: mirrorPreview ?? this.mirrorPreview,
      mirrorOutput: mirrorOutput ?? this.mirrorOutput,
      virtualCameraActive: virtualCameraActive ?? this.virtualCameraActive,
      beautyEnabled: beautyEnabled ?? this.beautyEnabled,
      compareMode: compareMode ?? this.compareMode,
      splitRatio: splitRatio ?? this.splitRatio,
      activeCategory: activeCategory ?? this.activeCategory,
      activeSubTool: activeSubTool ?? this.activeSubTool,
      beauty: beauty ?? this.beauty,
      face: face ?? this.face,
      makeup: makeup ?? this.makeup,
      filterId: filterId ?? this.filterId,
      filterIntensity: filterIntensity ?? this.filterIntensity,
      color: color ?? this.color,
      background: background ?? this.background,
      presets: presets ?? this.presets,
      activePresetId: activePresetId ?? this.activePresetId,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class CameraController extends StateNotifier<CameraState> {
  final BeautyNativeApi _api;
  Timer? _statsTimer;

  CameraController(this._api) : super(const CameraState()) {
    _init();
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _api.stopCamera();
    super.dispose();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    await _api.initialize();

    // Request camera permission
    final granted = await _api.requestCameraPermission();
    if (!granted) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Camera access required. Click below to grant permission.',
      );
    }

    // Load presets
    final customPresets = await PresetStorage.loadCustomPresets();
    final allPresets = [...PresetModel.defaultPresets, ...customPresets];

    // Load cameras
    final cameras = await _api.getCameras();
    CameraDevice? defaultCam;
    if (cameras.isNotEmpty) {
      defaultCam = cameras.firstWhere((c) => c.isDefault, orElse: () => cameras.first);
    }

    state = state.copyWith(
      cameras: cameras,
      selectedCamera: defaultCam,
      presets: allPresets,
      isLoading: false,
    );

    if (granted && defaultCam != null) {
      await startCamera(defaultCam);
    }

    // Start performance metrics polling
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (state.isStreaming) {
        final stats = await _api.getPerformanceStats();
        state = state.copyWith(stats: stats);
      }
    });
  }

  Future<void> refreshCameras() async {
    final cameras = await _api.getCameras();
    state = state.copyWith(cameras: cameras);
  }

  Future<void> openCameraSettings() async {
    await _api.openCameraSettings();
  }

  Future<void> retryPermissionAndStart() async {
    final granted = await _api.requestCameraPermission();
    if (granted) {
      await refreshCameras();
      if (state.selectedCamera != null) {
        await startCamera(state.selectedCamera!);
      } else if (state.cameras.isNotEmpty) {
        await startCamera(state.cameras.first);
      }
    } else {
      await openCameraSettings();
    }
  }

  Future<void> startCamera(CameraDevice device) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final dims = state.resolution.split('x');
      final width = int.tryParse(dims[0]) ?? 1920;
      final height = int.tryParse(dims[1]) ?? 1080;

      final textureId = await _api.startCamera(
        deviceId: device.id,
        width: width,
        height: height,
        fps: state.fps,
      );

      state = state.copyWith(
        selectedCamera: device,
        textureId: textureId,
        isStreaming: true,
        isLoading: false,
      );

      // Sync active settings to native pipeline
      await _syncAllSettings();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to start camera: $e',
      );
    }
  }

  Future<void> switchCamera(CameraDevice device) async {
    if (state.selectedCamera?.id == device.id && state.isStreaming) return;
    await _api.stopCamera();
    await startCamera(device);
  }

  Future<void> setResolution(String resolution, int fps) async {
    if (state.resolution == resolution && state.fps == fps) return;
    state = state.copyWith(resolution: resolution, fps: fps);
    if (state.selectedCamera != null) {
      await startCamera(state.selectedCamera!);
    }
  }

  void toggleMirrorPreview() {
    state = state.copyWith(mirrorPreview: !state.mirrorPreview);
  }

  Future<void> toggleVirtualCamera() async {
    if (state.virtualCameraActive) {
      await _api.stopVirtualCamera();
      state = state.copyWith(virtualCameraActive: false);
    } else {
      final success = await _api.startVirtualCamera();
      state = state.copyWith(virtualCameraActive: success);
    }
  }

  Future<void> toggleBeautyEnabled() async {
    final newEnabled = !state.beautyEnabled;
    state = state.copyWith(beautyEnabled: newEnabled);
    await _api.enableBeauty(newEnabled);
  }

  Future<void> setCompareMode(String mode, [double? splitRatio]) async {
    final newRatio = splitRatio ?? state.splitRatio;
    state = state.copyWith(compareMode: mode, splitRatio: newRatio);
    await _api.setCompareMode(mode: mode, splitRatio: newRatio);
  }

  Future<void> setSplitRatio(double ratio) async {
    state = state.copyWith(splitRatio: ratio);
    await _api.setCompareMode(mode: state.compareMode, splitRatio: ratio);
  }

  void selectCategory(String category) {
    String defaultTool = 'smooth';
    if (category == 'reshape') defaultTool = 'slimFace';
    if (category == 'makeup') defaultTool = 'lip';
    if (category == 'filter') defaultTool = 'filter';
    if (category == 'color') defaultTool = 'exposure';
    if (category == 'background') defaultTool = 'blur';
    if (category == 'presets') defaultTool = 'presets';

    state = state.copyWith(
      activeCategory: category,
      activeSubTool: defaultTool,
    );
  }

  void selectSubTool(String tool) {
    state = state.copyWith(activeSubTool: tool);
  }

  // --- Parameter Updates ---
  Future<void> updateBeauty(BeautySettings beauty) async {
    state = state.copyWith(beauty: beauty, activePresetId: null);
    await _api.setBeautySettings(beauty.toMap());
  }

  Future<void> updateFace(FaceSettings face) async {
    state = state.copyWith(face: face, activePresetId: null);
    await _api.setFaceSettings(face.toMap());
  }

  Future<void> updateMakeup(MakeupSettings makeup) async {
    state = state.copyWith(makeup: makeup, activePresetId: null);
    await _api.setMakeupSettings(makeup.toMap());
  }

  Future<void> updateFilter(String filterId, double intensity) async {
    state = state.copyWith(
      filterId: filterId,
      filterIntensity: intensity,
      activePresetId: null,
    );
    await _api.setFilter(filterId: filterId, intensity: intensity / 100.0);
  }

  Future<void> updateColor(ColorSettings color) async {
    state = state.copyWith(color: color, activePresetId: null);
    await _api.setColorSettings(color.toMap());
  }

  Future<void> updateBackground(BackgroundSettings background) async {
    state = state.copyWith(background: background, activePresetId: null);
    await _api.setBackgroundSettings(background.toMap());
  }

  // --- Reset Methods ---
  Future<void> resetBeauty() async {
    await updateBeauty(const BeautySettings());
  }

  Future<void> resetFace() async {
    await updateFace(const ReshapeSettings());
  }

  Future<void> resetMakeup() async {
    await updateMakeup(const MakeupSettings());
  }

  Future<void> resetFilter() async {
    await updateFilter('original', 80);
  }

  Future<void> resetColor() async {
    await updateColor(const ColorSettings());
  }

  Future<void> resetBackground() async {
    await updateBackground(const BackgroundSettings());
  }

  Future<void> resetAll() async {
    state = state.copyWith(
      beauty: const BeautySettings(),
      face: const ReshapeSettings(),
      makeup: const MakeupSettings(),
      filterId: 'original',
      filterIntensity: 80,
      color: const ColorSettings(),
      background: const BackgroundSettings(),
      activePresetId: null,
    );
    await _syncAllSettings();
  }

  // --- Presets ---
  Future<void> applyPreset(PresetModel preset) async {
    state = state.copyWith(
      beauty: preset.beauty,
      face: preset.face,
      makeup: preset.makeup,
      filterId: preset.filterId,
      filterIntensity: preset.filterIntensity,
      color: preset.color,
      background: preset.background,
      activePresetId: preset.id,
    );
    await _syncAllSettings();
  }

  Future<void> saveCurrentAsPreset(String name) async {
    final newPreset = PresetModel(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      isBuiltIn: false,
      beauty: state.beauty,
      face: state.face,
      makeup: state.makeup,
      filterId: state.filterId,
      filterIntensity: state.filterIntensity,
      color: state.color,
      background: state.background,
    );

    final updatedPresets = [...state.presets, newPreset];
    state = state.copyWith(
      presets: updatedPresets,
      activePresetId: newPreset.id,
    );
    await PresetStorage.saveCustomPresets(updatedPresets);
  }

  Future<void> deleteCustomPreset(String id) async {
    final updatedPresets = state.presets.where((p) => p.id != id || p.isBuiltIn).toList();
    state = state.copyWith(
      presets: updatedPresets,
      activePresetId: state.activePresetId == id ? null : state.activePresetId,
    );
    await PresetStorage.saveCustomPresets(updatedPresets);
  }

  Future<void> _syncAllSettings() async {
    await Future.wait([
      _api.setBeautySettings(state.beauty.toMap()),
      _api.setFaceSettings(state.face.toMap()),
      _api.setMakeupSettings(state.makeup.toMap()),
      _api.setFilter(filterId: state.filterId, intensity: state.filterIntensity / 100.0),
      _api.setColorSettings(state.color.toMap()),
      _api.setBackgroundSettings(state.background.toMap()),
      _api.enableBeauty(state.beautyEnabled),
      _api.setCompareMode(mode: state.compareMode, splitRatio: state.splitRatio),
    ]);
  }
}

final beautyNativeApiProvider = Provider<BeautyNativeApi>((ref) => BeautyNativeApi());

final cameraControllerProvider = StateNotifierProvider<CameraController, CameraState>((ref) {
  final api = ref.watch(beautyNativeApiProvider);
  return CameraController(api);
});
