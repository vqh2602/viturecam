import 'package:flutter/material.dart';

class ToolButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? customIcon;
  final bool isSelected;
  final bool isActive;
  final Widget? trailing;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  const ToolButton({
    super.key,
    required this.label,
    this.icon,
    this.customIcon,
    this.isSelected = false,
    this.isActive = false,
    this.trailing,
    required this.onTap,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2B2B30) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF7597).withValues(alpha: 0.6) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (customIcon != null)
              customIcon!
            else if (icon != null)
              Icon(
                icon,
                size: 16,
                color: isSelected ? const Color(0xFFFF8DA1) : (isActive ? Colors.white : Colors.white60),
              ),
            if (icon != null || customIcon != null) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : (isActive ? Colors.white : Colors.white60),
              ),
            ),
            ?trailing,
            if (isActive) ...[
              const SizedBox(width: 4),
              Container(
                width: 4.5,
                height: 4.5,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF7597),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
