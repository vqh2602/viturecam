import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/beauty_slider.dart';
import '../../widgets/tool_button.dart';
import '../camera/camera_controller.dart';

class BackgroundPanel extends ConsumerWidget {
  const BackgroundPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);
    final bg = state.background;

    final modes = [
      {'id': 'none', 'label': l10n.bgModeNone, 'icon': Icons.block},
      {'id': 'portrait_blur', 'label': l10n.bgModePortraitBlur, 'icon': Icons.lens_blur},
      {'id': 'strong_blur', 'label': l10n.bgModeStrongBlur, 'icon': Icons.blur_circular},
      {'id': 'virtual_studio', 'label': l10n.bgModeStudio, 'icon': Icons.camera},
      {'id': 'zoom_blur', 'label': l10n.bgModeZoomBlur, 'icon': Icons.center_focus_strong},
      {'id': 'swirly_bokeh', 'label': l10n.bgModeSwirlyBokeh, 'icon': Icons.rotate_right},
      {'id': 'dreamy_blur', 'label': l10n.bgModeDreamyGlow, 'icon': Icons.auto_awesome},
      {'id': 'motion_blur', 'label': l10n.bgModeMotionBlur, 'icon': Icons.compare_arrows},
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: bg.mode != 'none'
              ? BeautySlider(
                  label: l10n.bgBlurIntensity,
                  value: bg.blurIntensity,
                  defaultValue: 50,
                  onChanged: (v) => controller.updateBackground(bg.copyWith(blurIntensity: v)),
                )
              : Center(
                  child: Text(
                    l10n.bgNonePlaceholder,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
        ),
        const Divider(height: 1, color: Colors.white10),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: Colors.white54),
                tooltip: l10n.resetBackgroundTooltip,
                onPressed: bg.isModified ? () => controller.resetBackground() : null,
              ),
              const SizedBox(width: 4),
              for (final m in modes)
                ToolButton(
                  label: m['label'] as String,
                  icon: m['icon'] as IconData,
                  isSelected: bg.mode == m['id'],
                  isActive: bg.mode == m['id'] && m['id'] != 'none',
                  onTap: () => controller.updateBackground(bg.copyWith(mode: m['id'] as String)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
