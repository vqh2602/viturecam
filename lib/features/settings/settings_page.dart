import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/locale_provider.dart';
import '../../l10n/app_localizations.dart';
import '../camera/camera_controller.dart';

class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(appLocaleProvider);
    final state = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);

    return Dialog(
      backgroundColor: const Color(0xFF1C1C20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings_outlined, color: Color(0xFFFF7597), size: 22),
                const SizedBox(width: 8),
                Text(
                  l10n.settingsTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),

            // Language Selector
            Text(
              l10n.language,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.languageSystem),
                  selected: currentLocale == null,
                  onSelected: (sel) {
                    if (sel) ref.read(appLocaleProvider.notifier).state = null;
                  },
                ),
                ChoiceChip(
                  label: Text(l10n.languageVi),
                  selected: currentLocale?.languageCode == 'vi',
                  onSelected: (sel) {
                    if (sel) ref.read(appLocaleProvider.notifier).state = const Locale('vi');
                  },
                ),
                ChoiceChip(
                  label: Text(l10n.languageEn),
                  selected: currentLocale?.languageCode == 'en',
                  onSelected: (sel) {
                    if (sel) ref.read(appLocaleProvider.notifier).state = const Locale('en');
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Video Format & FPS
            Text(
              l10n.captureFormatFramerate,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('1080p @ 30 FPS'),
                  selected: state.resolution == '1920x1080' && state.fps == 30,
                  onSelected: (sel) {
                    if (sel) controller.setResolution('1920x1080', 30);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('720p @ 60 FPS'),
                  selected: state.resolution == '1280x720' && state.fps == 60,
                  onSelected: (sel) {
                    if (sel) controller.setResolution('1280x720', 60);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Virtual Camera Info
            Text(
              l10n.virtualCameraHeader,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF26262B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        l10n.virtualDeviceName,
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      const Text(
                        'Beauty Camera',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFF8DA1)),
                      ),
                      const Spacer(),
                      Text(
                        state.virtualCameraActive ? l10n.virtualCamActive : l10n.virtualCamStandby,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: state.virtualCameraActive ? const Color(0xFF4CAF50) : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.virtualCamDescription,
                    style: const TextStyle(fontSize: 11, color: Colors.white54, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Performance Stats
            Text(
              l10n.hardwarePipelineStats,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatCard(title: l10n.statFps, value: state.stats.fps.toStringAsFixed(1)),
                const SizedBox(width: 8),
                _StatCard(title: l10n.statProcessing, value: '${state.stats.processingTimeMs.toStringAsFixed(1)} ms'),
                const SizedBox(width: 8),
                _StatCard(title: l10n.statTracking, value: '${state.stats.trackingTimeMs.toStringAsFixed(1)} ms'),
                const SizedBox(width: 8),
                _StatCard(title: l10n.statDropped, value: '${state.stats.droppedFrames}'),
                const SizedBox(width: 8),
                _StatCard(title: l10n.statResolution, value: '${state.stats.width}x${state.stats.height}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF26262B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 10.5, color: Colors.white38)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
