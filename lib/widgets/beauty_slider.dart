import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class BeautySlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final double defaultValue;
  final ValueChanged<double> onChanged;
  final VoidCallback? onReset;
  final String? unit;

  const BeautySlider({
    super.key,
    required this.label,
    required this.value,
    this.min = 0,
    this.max = 100,
    this.defaultValue = 0,
    required this.onChanged,
    this.onReset,
    this.unit,
  });

  bool get isModified => (value - defaultValue).abs() > 0.5;

  @override
  Widget build(BuildContext context) {
    final isCentered = min < 0;
    final displayVal = value.round();
    final valueText = isCentered && displayVal > 0 ? '+$displayVal' : '$displayVal';
    final resetAction = onReset ?? () => onChanged(defaultValue);

    return GestureDetector(
      onDoubleTap: resetAction,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                if (isModified) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF7597),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: isModified ? resetAction : null,
                  child: Text(
                    '$valueText${unit ?? ''}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isModified ? const Color(0xFFFF8DA1) : Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _SliderResetButton(
                  isModified: isModified,
                  defaultValueText: '${defaultValue.round()}${unit ?? ''}',
                  onReset: resetAction,
                ),
              ],
            ),
            const SizedBox(height: 2),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: const Color(0xFFFF7597),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6, elevation: 2),
                overlayColor: const Color(0xFFFF7597).withValues(alpha: 0.2),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 11),
              ),
              child: SizedBox(
                height: 22,
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: (newVal) {
                    // Magnetic snapping near defaultValue to make returning to 0 effortless
                    if ((newVal - defaultValue).abs() <= 1.5) {
                      onChanged(defaultValue);
                    } else {
                      onChanged(newVal);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderResetButton extends StatefulWidget {
  final bool isModified;
  final String defaultValueText;
  final VoidCallback onReset;

  const _SliderResetButton({
    required this.isModified,
    required this.defaultValueText,
    required this.onReset,
  });

  @override
  State<_SliderResetButton> createState() => _SliderResetButtonState();
}

class _SliderResetButtonState extends State<_SliderResetButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resetWord = l10n?.reset ?? 'Reset';
    final tooltipText = '$resetWord (${widget.defaultValueText})';

    final Color iconColor;
    final Color bgColor;
    final Color borderColor;

    if (widget.isModified) {
      if (_isHovered) {
        iconColor = Colors.white;
        bgColor = const Color(0xFFFF7597);
        borderColor = const Color(0xFFFF7597);
      } else {
        iconColor = const Color(0xFFFF7597);
        bgColor = const Color(0xFFFF7597).withValues(alpha: 0.16);
        borderColor = const Color(0xFFFF7597).withValues(alpha: 0.35);
      }
    } else {
      iconColor = Colors.white.withValues(alpha: 0.18);
      bgColor = Colors.transparent;
      borderColor = Colors.white.withValues(alpha: 0.08);
    }

    return Tooltip(
      message: widget.isModified ? tooltipText : '$resetWord (${widget.defaultValueText})',
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: widget.isModified ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.isModified ? widget.onReset : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.restart_alt_rounded,
                size: 14,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
