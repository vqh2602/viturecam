import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'patreon_config_dialog.dart';
import 'patreon_provider.dart';

class PatreonPaywallView extends ConsumerWidget {
  const PatreonPaywallView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(patreonProvider);
    final notifier = ref.read(patreonProvider.notifier);

    return Container(
      width: double.infinity,
      height: 113,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF16161B),
        border: const Border(top: BorderSide(color: Colors.white10)),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF16161B),
            const Color(0xFFFF424D).withValues(alpha: 0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: state.isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF424D))),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.patreonChecking,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            )
          : Row(
              children: [
                // Left: Crown / Lock Icon with Patreon Brand Glow
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF424D), Color(0xFFFF7597)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF424D).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.lock_person_rounded, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 14),

                // Center: Information & Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.makeupLockedTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF424D).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFFF424D).withValues(alpha: 0.5), width: 0.8),
                            ),
                            child: const Text(
                              'VIP',
                              style: TextStyle(color: Color(0xFFFF7597), fontSize: 9.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.makeupLockedSubtitle,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (state.isLoggedIn && !state.isPatron) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFFFFB300), size: 13),
                            const SizedBox(width: 5),
                            Text(
                              '${state.fullName} (${state.email}) — ${l10n.patreonInactive}',
                              style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          state.errorMessage!,
                          style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 10.5),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Right: Action Buttons in a horizontal Row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!state.isLoggedIn) ...[
                      // Button 1: Login with Patreon
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (!state.config.isConfigured) {
                            PatreonConfigDialog.show(context);
                          } else {
                            await notifier.loginWithOAuth();
                          }
                        },
                        icon: const Icon(Icons.login_rounded, size: 14),
                        label: Text(l10n.patreonLogin),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF424D),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => notifier.openCampaign(),
                        icon: const Icon(Icons.favorite_rounded, size: 13, color: Color(0xFFFF7597)),
                        label: Text(l10n.patreonSupportProject),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => PatreonConfigDialog.show(context),
                        icon: const Icon(Icons.tune_rounded, size: 16, color: Colors.white60),
                        tooltip: 'Cấu hình OAuth / Dùng thử',
                        splashRadius: 16,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ] else ...[
                      // Logged in but not active patron
                      ElevatedButton.icon(
                        onPressed: () => notifier.checkMembershipStatus(),
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: Text(l10n.patreonCheck),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E2E36),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Colors.white24),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => notifier.openCampaign(),
                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                        label: Text(l10n.patreonSupportProject),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF424D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        onPressed: () => notifier.logout(),
                        icon: const Icon(Icons.logout_rounded, size: 13, color: Colors.white38),
                        label: Text(l10n.patreonLogout, style: const TextStyle(fontSize: 11, color: Colors.white38)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
    );
  }
}
