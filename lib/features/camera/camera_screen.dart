import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/tool_button.dart';
import '../../widgets/vip_badge.dart';
import '../background/background_panel.dart';
import '../beauty/beauty_panel.dart';
import '../color/color_panel.dart';
import '../filters/filter_panel.dart';
import '../makeup/makeup_panel.dart';
import '../presets/preset_panel.dart';
import '../reshape/reshape_panel.dart';
import '../settings/settings_page.dart';
import '../patreon/patreon_provider.dart';
import '../updater/update_dialog.dart';
import '../../services/update_provider.dart';
import 'camera_controller.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  bool _isHoldingRaw = false;
  String _savedCompareModeBeforeHold = 'none';
  Timer? _autoUpdateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoUpdate();
    });
  }

  @override
  void dispose() {
    _autoUpdateTimer?.cancel();
    super.dispose();
  }

  void _checkAutoUpdate() {
    _autoUpdateTimer = Timer(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      final updateService = ref.read(updateServiceProvider);
      final release = await updateService.checkForUpdate();
      if (release != null && mounted) {
        final currentVersion = await updateService.getCurrentVersion();
        if (mounted) {
          UpdateDialog.show(
            context,
            release: release,
            currentVersion: currentVersion,
            updateService: updateService,
          );
        }
      }
    });
  }

  void _onBeforeAfterDown() {
    if (_isHoldingRaw) return;
    final currentMode = ref.read(cameraControllerProvider).compareMode;
    if (currentMode != 'raw') {
      _savedCompareModeBeforeHold = currentMode;
    }
    setState(() => _isHoldingRaw = true);
    ref.read(cameraControllerProvider.notifier).setCompareMode('raw');
  }

  void _onBeforeAfterUp() {
    if (!_isHoldingRaw) return;
    setState(() => _isHoldingRaw = false);
    final restoreMode = _savedCompareModeBeforeHold == 'raw' ? 'none' : _savedCompareModeBeforeHold;
    ref.read(cameraControllerProvider.notifier).setCompareMode(restoreMode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF141417),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(context, state, controller),
            if (state.virtualCamera.message.isNotEmpty || (state.virtualCameraReinstalled && state.virtualCamera.state != 'installing'))
              Container(
                width: double.infinity,
                color: (state.virtualCameraReinstalled && state.virtualCamera.state != 'installing')
                    ? const Color(0xFF2B1C28)
                    : (state.virtualCamera.state == 'error'
                        ? const Color(0xFF381C1C)
                        : (state.virtualCamera.state == 'approval'
                            ? const Color(0xFF332912)
                            : const Color(0xFF1B2E22))),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      (state.virtualCameraReinstalled && state.virtualCamera.state != 'installing')
                          ? Icons.restart_alt_rounded
                          : (state.virtualCamera.state == 'error'
                              ? Icons.error_outline
                              : (state.virtualCamera.state == 'approval'
                                  ? Icons.admin_panel_settings_outlined
                                  : Icons.info_outline)),
                      size: 18,
                      color: (state.virtualCameraReinstalled && state.virtualCamera.state != 'installing')
                          ? const Color(0xFFFF8DA1)
                          : (state.virtualCamera.state == 'error'
                              ? const Color(0xFFFF6B6B)
                              : (state.virtualCamera.state == 'approval'
                                  ? const Color(0xFFFFD166)
                                  : const Color(0xFF7FE68D))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (state.virtualCameraReinstalled && state.virtualCamera.state != 'installing')
                            ? (state.virtualCamera.message.isNotEmpty
                                ? '${state.virtualCamera.message} • ${l10n.restartAppAfterReinstallTip}'
                                : l10n.restartAppAfterReinstallTip)
                            : state.virtualCamera.message,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (state.virtualCameraReinstalled && state.virtualCamera.state != 'installing') ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7597),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        icon: const Icon(Icons.restart_alt_rounded, size: 14),
                        label: Text(
                          l10n.restartApp,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => controller.restartApp(),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (state.virtualCamera.state == 'error' || state.virtualCamera.state == 'approval') ...[
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7597).withValues(alpha: 0.18),
                          foregroundColor: const Color(0xFFFF8DA1),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: const BorderSide(color: Color(0xFFFF7597), width: 0.8),
                          ),
                        ),
                        icon: const Icon(Icons.build_circle_outlined, size: 14),
                        label: Text(
                          l10n.reinstallExtension,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        onPressed: state.virtualCamera.pending
                            ? null
                            : () => controller.reinstallVirtualCamera(),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: const BorderSide(color: Colors.white24, width: 0.8),
                          ),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 13),
                        label: Text(
                          l10n.openSystemSettings,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () => controller.openCameraExtensionSettings(),
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                      tooltip: l10n.none,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: () => controller.dismissVirtualCameraMessage(),
                    ),
                  ],
                ),
              ),

            // Live Camera Viewport
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildCameraPreview(state, controller),

                  // Draggable Split Divider when in split compare mode
                  if (state.compareMode == 'split')
                    _buildSplitDivider(state, controller),

                  // Floating Before/After Comparison Controls
                  Positioned(
                    bottom: 16,
                    left: 20,
                    child: _buildCompareFloatingControls(state, controller),
                  ),

                  // Floating Original Camera Banner when holding original
                  if (_isHoldingRaw)
                    Positioned(
                      top: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFF7597), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF7597).withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.remove_red_eye, color: Color(0xFFFF7597), size: 14),
                            const SizedBox(width: 6),
                            Text(
                              l10n.camRawBanner,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Floating Performance Stats Badge
                  Positioned(
                    top: 14,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: state.isStreaming ? const Color(0xFF4CAF50) : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${state.stats.fps.toStringAsFixed(0)} FPS • ${state.stats.processingTimeMs.toStringAsFixed(1)}ms',
                            style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Loading / Error indicator
                  if (state.isLoading)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: CircularProgressIndicator(color: Color(0xFFFF7597)),
                      ),
                    ),
                  if (state.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      margin: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E1C22),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFF7597).withValues(alpha: 0.6)),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_off, color: Color(0xFFFF7597), size: 36),
                          const SizedBox(height: 10),
                          Text(
                            state.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF7597),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.lock_open, size: 16),
                                label: Text(l10n.grantPermission),
                                onPressed: () => controller.retryPermissionAndStart(),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: Colors.white24),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.settings, size: 16),
                                label: Text(l10n.systemSettings),
                                onPressed: () => controller.openCameraSettings(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Beauty Dock
            _buildBottomDock(context, state, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, CameraState state, CameraController controller) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF19191D),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          // Logo & Title
          const Icon(Icons.auto_awesome, color: Color(0xFFFF7597), size: 20),
          const SizedBox(width: 8),
          Text(
            l10n.appTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 24),

          // Camera selector dropdown
          if (state.cameras.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF26262C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: state.selectedCamera?.id,
                  dropdownColor: const Color(0xFF26262C),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white70),
                  isDense: true,
                  style: const TextStyle(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w500),
                  items: state.cameras.map((cam) {
                    return DropdownMenuItem<String>(
                      value: cam.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_outlined, size: 14, color: Color(0xFFFF8DA1)),
                          const SizedBox(width: 6),
                          Text(cam.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newId) {
                    if (newId != null) {
                      final selected = state.cameras.firstWhere((c) => c.id == newId);
                      controller.switchCamera(selected);
                    }
                  },
                ),
              ),
            ),

          const Spacer(),

          // Mirror Preview toggle
          IconButton(
            icon: Icon(
              Icons.flip,
              size: 18,
              color: state.mirrorPreview ? const Color(0xFFFF8DA1) : Colors.white54,
            ),
            tooltip: l10n.mirrorPreview,
            onPressed: () => controller.toggleMirrorPreview(),
          ),

          // Beauty Master Toggle
          IconButton(
            icon: Icon(
              state.beautyEnabled ? Icons.face_retouching_natural : Icons.face,
              size: 20,
              color: state.beautyEnabled ? const Color(0xFFFF7597) : Colors.white38,
            ),
            tooltip: state.beautyEnabled ? l10n.disableBeauty : l10n.enableBeauty,
            onPressed: () => controller.toggleBeautyEnabled(),
          ),
          const SizedBox(width: 6),

          // Virtual Camera Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: state.virtualCameraActive ? const Color(0xFF2E4C33) : const Color(0xFF26262C),
              foregroundColor: state.virtualCameraActive ? const Color(0xFF7FE68D) : Colors.white70,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: state.virtualCameraActive ? const Color(0xFF4CAF50) : Colors.white12,
                ),
              ),
            ),
            icon: Icon(
              Icons.sensors,
              size: 15,
              color: state.virtualCameraActive ? const Color(0xFF7FE68D) : Colors.white54,
            ),
            label: Text(
              state.virtualCameraActive
                  ? l10n.virtualCamOn
                  : state.virtualCamera.pending
                      ? l10n.virtualCamSetup
                      : l10n.virtualCam,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            onPressed: state.virtualCamera.pending ? null : () => controller.toggleVirtualCamera(),
          ),
          const SizedBox(width: 8),

          // Settings Button
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 19, color: Colors.white70),
            tooltip: l10n.settings,
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const SettingsDialog(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview(CameraState state, CameraController controller) {
    final l10n = AppLocalizations.of(context)!;
    if (state.textureId == null || !state.isStreaming) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined, size: 48, color: Colors.white24),
              const SizedBox(height: 12),
              Text(l10n.cameraOffline, style: const TextStyle(color: Colors.white54, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Transform.scale(
                scaleX: state.mirrorPreview ? -1 : 1,
                child: Texture(textureId: state.textureId!),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSplitDivider(CameraState state, CameraController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final splitX = constraints.maxWidth * state.splitRatio;

        return Positioned(
          left: splitX - 16,
          top: 0,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) {
              final newRatio = (splitX + details.delta.dx) / constraints.maxWidth;
              controller.setSplitRatio(newRatio.clamp(0.05, 0.95));
            },
            child: SizedBox(
              width: 32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(width: 2, color: Colors.white70),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E22),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                    ),
                    child: const Icon(Icons.compare_arrows, size: 16, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompareFloatingControls(CameraState state, CameraController controller) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hold to view original
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _onBeforeAfterDown(),
            onPointerUp: (_) => _onBeforeAfterUp(),
            onPointerCancel: (_) => _onBeforeAfterUp(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isHoldingRaw ? const Color(0xFFFF7597) : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility,
                    size: 14,
                    color: _isHoldingRaw ? Colors.white : Colors.white70,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    l10n.holdOriginal,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _isHoldingRaw ? Colors.white : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 16, color: Colors.white12),
          // Split Screen toggle
          GestureDetector(
            onTap: () {
              final newMode = state.compareMode == 'split' ? 'none' : 'split';
              controller.setCompareMode(newMode);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: state.compareMode == 'split' ? const Color(0xFFFF7597) : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.vertical_split,
                    size: 14,
                    color: state.compareMode == 'split' ? Colors.white : Colors.white70,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    l10n.split,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: state.compareMode == 'split' ? Colors.white : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomDock(BuildContext context, CameraState state, CameraController controller) {
    final l10n = AppLocalizations.of(context)!;
    final patreonState = ref.watch(patreonProvider);
    final activeCat = state.activeCategory;

    final categories = [
      {'id': 'beauty', 'label': l10n.categoryBeauty, 'icon': Icons.face_retouching_natural, 'isActive': state.beauty.isModified},
      {'id': 'reshape', 'label': l10n.categoryReshape, 'icon': Icons.architecture, 'isActive': state.face.isModified},
      {'id': 'makeup', 'label': l10n.categoryMakeup, 'icon': Icons.brush, 'isActive': state.makeup.isModified},
      {'id': 'filter', 'label': l10n.categoryFilter, 'icon': Icons.filter, 'isActive': state.filterId != 'original'},
      {'id': 'color', 'label': l10n.categoryColor, 'icon': Icons.tune, 'isActive': state.color.isModified},
      {'id': 'background', 'label': l10n.categoryBackground, 'icon': Icons.blur_on, 'isActive': state.background.isModified},
      {'id': 'presets', 'label': l10n.categoryPresets, 'icon': Icons.auto_awesome_motion, 'isActive': state.activePresetId != null},
    ];

    Widget activePanel;
    switch (activeCat) {
      case 'reshape':
        activePanel = const ReshapePanel();
        break;
      case 'makeup':
        activePanel = const MakeupPanel();
        break;
      case 'filter':
        activePanel = const FilterPanel();
        break;
      case 'color':
        activePanel = const ColorPanel();
        break;
      case 'background':
        activePanel = const BackgroundPanel();
        break;
      case 'presets':
        activePanel = const PresetPanel();
        break;
      case 'beauty':
      default:
        activePanel = const BeautyPanel();
        break;
    }

    return Container(
      height: 168,
      decoration: const BoxDecoration(
        color: Color(0xFF18181C),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          // Sub-panel for active category with constant height across all modes
          SizedBox(
            height: 113,
            child: activePanel,
          ),

          const Divider(height: 1, color: Colors.white10),

          // Main horizontal category toolbar (Xingtu style)
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final cat in categories)
                        ToolButton(
                          label: cat['label'] as String,
                          icon: cat['icon'] as IconData,
                          isSelected: activeCat == cat['id'],
                          isActive: cat['isActive'] as bool,
                          trailing: cat['id'] == 'makeup'
                              ? VipBadge(isPatron: patreonState.isPatron)
                              : null,
                          onTap: () => controller.selectCategory(cat['id'] as String),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 16, color: Colors.white12),
                // Reset All Button
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white60,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: Text(l10n.resetAll, style: const TextStyle(fontSize: 12)),
                  onPressed: () => controller.resetAll(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
