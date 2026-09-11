import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/tool_button.dart';
import '../background/background_panel.dart';
import '../beauty/beauty_panel.dart';
import '../color/color_panel.dart';
import '../filters/filter_panel.dart';
import '../makeup/makeup_panel.dart';
import '../presets/preset_panel.dart';
import '../reshape/reshape_panel.dart';
import '../settings/settings_page.dart';
import 'camera_controller.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  bool _isHoldingRaw = false;

  void _onBeforeAfterDown() {
    setState(() => _isHoldingRaw = true);
    ref.read(cameraControllerProvider.notifier).setCompareMode('raw');
  }

  void _onBeforeAfterUp() {
    setState(() => _isHoldingRaw = false);
    final prevMode = ref.read(cameraControllerProvider).compareMode == 'raw' ? 'none' : ref.read(cameraControllerProvider).compareMode;
    ref.read(cameraControllerProvider.notifier).setCompareMode(prevMode);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF141417),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(context, state, controller),

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
                            '${state.stats.fps.toStringAsFixed(0)} FPS • ${state.stats.renderTimeMs.toStringAsFixed(1)}ms',
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
                                label: const Text('Grant Permission'),
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
                                label: const Text('System Settings'),
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
          const Text(
            'Beauty Camera',
            style: TextStyle(
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
            tooltip: 'Mirror Preview',
            onPressed: () => controller.toggleMirrorPreview(),
          ),

          // Beauty Master Toggle
          IconButton(
            icon: Icon(
              state.beautyEnabled ? Icons.face_retouching_natural : Icons.face,
              size: 20,
              color: state.beautyEnabled ? const Color(0xFFFF7597) : Colors.white38,
            ),
            tooltip: state.beautyEnabled ? 'Disable Beauty Effects' : 'Enable Beauty Effects',
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
              state.virtualCameraActive ? 'Virtual Cam: ON' : 'Virtual Cam',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            onPressed: () => controller.toggleVirtualCamera(),
          ),
          const SizedBox(width: 8),

          // Settings Button
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 19, color: Colors.white70),
            tooltip: 'Settings',
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
    if (state.textureId == null || !state.isStreaming) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_outlined, size: 48, color: Colors.white24),
              SizedBox(height: 12),
              Text('Camera Offline', style: TextStyle(color: Colors.white54, fontSize: 14)),
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
            onPointerDown: (_) => _onBeforeAfterDown(),
            onPointerUp: (_) => _onBeforeAfterUp(),
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
                    'Hold: Original',
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
                    'Split',
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
    final activeCat = state.activeCategory;

    final categories = [
      {'id': 'beauty', 'label': 'Beauty', 'icon': Icons.face_retouching_natural, 'isActive': state.beauty.isModified},
      {'id': 'reshape', 'label': 'Reshape', 'icon': Icons.architecture, 'isActive': state.face.isModified},
      {'id': 'makeup', 'label': 'Makeup', 'icon': Icons.brush, 'isActive': state.makeup.isModified},
      {'id': 'filter', 'label': 'Filter', 'icon': Icons.filter, 'isActive': state.filterId != 'original'},
      {'id': 'color', 'label': 'Color', 'icon': Icons.tune, 'isActive': state.color.isModified},
      {'id': 'background', 'label': 'Background', 'icon': Icons.blur_on, 'isActive': state.background.isModified},
      {'id': 'presets', 'label': 'Presets', 'icon': Icons.auto_awesome_motion, 'isActive': state.activePresetId != null},
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
      decoration: const BoxDecoration(
        color: Color(0xFF18181C),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sub-panel for active category
          activePanel,

          const Divider(height: 1, color: Colors.white10),

          // Main horizontal category toolbar (Xingtu style)
          Container(
            height: 54,
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
                  label: const Text('Reset All', style: TextStyle(fontSize: 12)),
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
