import 'package:flutter/material.dart';
import '../features/patreon/patreon_config_dialog.dart';

/// Small badge indicating VIP status or locked state.
class VipBadge extends StatelessWidget {
  final bool isPatron;
  final EdgeInsetsGeometry margin;

  const VipBadge({
    super.key,
    required this.isPatron,
    this.margin = const EdgeInsets.only(left: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: isPatron
            ? const Color(0xFFFF7597).withValues(alpha: 0.2)
            : const Color(0xFFFF424D).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isPatron
              ? const Color(0xFFFF7597).withValues(alpha: 0.5)
              : const Color(0xFFFF424D).withValues(alpha: 0.5),
          width: 0.6,
        ),
      ),
      child: Text(
        isPatron ? 'VIP' : 'LOCK',
        style: TextStyle(
          color: isPatron ? const Color(0xFFFF8DA1) : const Color(0xFFFF8A80),
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Sleek inline banner for non-patrons attempting to use a VIP tool or slider.
class VipInlineBanner extends StatelessWidget {
  final String featureName;
  final VoidCallback? onUnlock;

  const VipInlineBanner({
    super.key,
    required this.featureName,
    this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    final isVi = Localizations.localeOf(context).languageCode.startsWith('vi');

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF22161A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFF424D).withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_person_rounded, size: 16, color: Color(0xFFFF7597)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isVi
                  ? '$featureName — Dành riêng cho thành viên VIP (Patreon)'
                  : '$featureName — Exclusive for Patreon VIP Supporters',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onUnlock ?? () => PatreonConfigDialog.show(context),
            icon: const Icon(Icons.stars_rounded, size: 13),
            label: Text(isVi ? 'Mở khóa VIP' : 'Unlock VIP'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF424D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }
}
