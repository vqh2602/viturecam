import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/locale_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/update_provider.dart';
import '../camera/camera_controller.dart';
import '../patreon/patreon_config_dialog.dart';
import '../patreon/patreon_provider.dart';
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
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
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
            const SizedBox(height: 8),

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

            // Patreon Membership Section
            const _PatreonSection(),
            const SizedBox(height: 20),

            // Software Update Section
            const _UpdateSection(),
          ],
        ),
      ),
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

class _PatreonSection extends ConsumerWidget {
  const _PatreonSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(patreonProvider);
    final notifier = ref.read(patreonProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.patreonTitle,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            IconButton(
              icon: const Icon(Icons.tune_rounded, size: 16, color: Colors.white54),
              tooltip: l10n.patreonConfig,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 16,
              onPressed: () => PatreonConfigDialog.show(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF26262B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: state.isPatron
                  ? const Color(0xFFFF424D).withValues(alpha: 0.3)
                  : Colors.white10,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Builder(
                    builder: (context) {
                      final avatarUrl = state.account?.avatarUrl;
                      return Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: state.isPatron
                              ? const Color(0xFFFF424D).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: state.isPatron
                                ? const Color(0xFFFF424D).withValues(alpha: 0.4)
                                : Colors.white12,
                          ),
                        ),
                        child: (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? ClipOval(
                                child: Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, size: 20, color: Colors.white70),
                                ),
                              )
                            : Icon(
                                state.isPatron ? Icons.stars_rounded : Icons.person_outline_rounded,
                                size: 20,
                                color: state.isPatron ? const Color(0xFFFF7597) : Colors.white54,
                              ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                state.isLoggedIn
                                    ? (state.fullName.isNotEmpty ? state.fullName : state.email)
                                    : l10n.patreonNotConnected,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: state.isPatron
                                    ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                                    : (state.isLoggedIn
                                        ? const Color(0xFFFF9800).withValues(alpha: 0.15)
                                        : Colors.white10),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: state.isPatron
                                      ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                                      : (state.isLoggedIn
                                          ? const Color(0xFFFF9800).withValues(alpha: 0.4)
                                          : Colors.white12),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                state.isTestMode
                                    ? l10n.patreonTestModeActive
                                    : (state.isPatron
                                        ? l10n.patreonActive
                                        : (state.isLoggedIn ? l10n.patreonInactive : l10n.patreonNotConnected)),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: state.isPatron
                                      ? const Color(0xFF81C784)
                                      : (state.isLoggedIn ? const Color(0xFFFFB74D) : Colors.white38),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          state.isLoggedIn
                              ? (state.isPatron && state.displayAmount.isNotEmpty
                                  ? l10n.patreonPledgedAmount(state.displayAmount)
                                  : (state.email.isNotEmpty ? state.email : 'Patreon Supporter'))
                              : l10n.patreonSupportProject,
                          style: const TextStyle(fontSize: 11, color: Colors.white54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFFF8A80)),
                ),
              ],
              if (state.successMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  state.successMessage!,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF81C784)),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!state.isLoggedIn) ...[
                    ElevatedButton.icon(
                      onPressed: state.isLoading
                          ? null
                          : () async {
                              if (!state.config.isConfigured) {
                                PatreonConfigDialog.show(context);
                              } else {
                                await notifier.loginWithOAuth();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF424D),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF28282D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      icon: state.isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white70)),
                            )
                          : const Icon(Icons.login_rounded, size: 15),
                      label: Text(
                        l10n.patreonLogin,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => notifier.openCampaign(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.favorite_rounded, size: 14, color: Color(0xFFFF7597)),
                      label: Text(
                        l10n.patreonSupportProject,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: state.isLoading ? null : () => notifier.checkMembershipStatus(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF323238),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF28282D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Colors.white12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: state.isLoading
                          ? const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white70)),
                            )
                          : const Icon(Icons.refresh_rounded, size: 15),
                      label: Text(
                        l10n.patreonCheck,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => notifier.openCampaign(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 13),
                      label: Text(
                        l10n.patreonSupportProject,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => notifier.logout(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white38,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 13),
                      label: Text(
                        l10n.patreonLogout,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

