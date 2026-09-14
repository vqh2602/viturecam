import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../camera/camera_controller.dart';

class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                const Text(
                  'Beauty Camera Settings',
                  style: TextStyle(
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

            // Video Format & FPS
            const Text(
              'Capture Format & Framerate',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
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
            const Text(
              'Virtual Camera (CoreMediaIO)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
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
                      const Text(
                        'Virtual Device Name: ',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      const Text(
                        'Beauty Camera',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFF8DA1)),
                      ),
                      const Spacer(),
                      Text(
                        state.virtualCameraActive ? 'ACTIVE' : 'STANDBY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: state.virtualCameraActive ? const Color(0xFF4CAF50) : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'When enabled, select "Beauty Camera" in Zoom, Google Meet, OBS, Discord, Telegram, or Microsoft Teams to use your beautified video stream directly.',
                    style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Performance Stats
            const Text(
              'Hardware & Pipeline Stats',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatCard(title: 'FPS', value: state.stats.fps.toStringAsFixed(1)),
                const SizedBox(width: 8),
                _StatCard(title: 'Processing', value: '${state.stats.processingTimeMs.toStringAsFixed(1)} ms'),
                const SizedBox(width: 8),
                _StatCard(title: 'Tracking', value: '${state.stats.trackingTimeMs.toStringAsFixed(1)} ms'),
                const SizedBox(width: 8),
                _StatCard(title: 'Dropped', value: '${state.stats.droppedFrames}'),
                const SizedBox(width: 8),
                _StatCard(title: 'Resolution', value: '${state.stats.width}x${state.stats.height}'),
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
