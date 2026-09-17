import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/locale_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/update_provider.dart';
import '../camera/camera_controller.dart';
import '../updater/update_dialog.dart';

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
            const SizedBox(height: 20),

            // Software Update Section
            const _UpdateSection(),
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

class _UpdateSection extends ConsumerStatefulWidget {
  const _UpdateSection();

  @override
  ConsumerState<_UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends ConsumerState<_UpdateSection> {
  bool _isChecking = false;
  String _currentVersion = '1.0.3';
  String? _statusMessage;
  bool _isLatest = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  void _loadCurrentVersion() async {
    final version = await ref.read(updateServiceProvider).getCurrentVersion();
    if (mounted) {
      setState(() {
        _currentVersion = version;
      });
    }
  }

  void _checkUpdate() async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
      _statusMessage = null;
      _isLatest = false;
    });

    final updateService = ref.read(updateServiceProvider);
    final l10n = AppLocalizations.of(context)!;

    try {
      final release = await updateService.checkForUpdate();
      if (!mounted) return;

      if (release != null) {
        setState(() {
          _isChecking = false;
        });
        UpdateDialog.show(
          context,
          release: release,
          currentVersion: _currentVersion,
          updateService: updateService,
        );
      } else {
        setState(() {
          _isChecking = false;
          _isLatest = true;
          _statusMessage = l10n.updateLatest(_currentVersion);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _isLatest = false;
        _statusMessage = l10n.updateError(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.softwareUpdate,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF26262B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              const Icon(Icons.system_update_rounded, color: Color(0xFFFF7597), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.updateCurrentVersion(_currentVersion),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 11,
                          color: _isLatest ? const Color(0xFF4CAF50) : const Color(0xFFFF8DA1),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _isChecking ? null : _checkUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF323238),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF28282D),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.white12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: _isChecking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white70)),
                      )
                    : Text(
                        l10n.updateCheck,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

