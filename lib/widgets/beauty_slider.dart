import 'package:flutter/material.dart';

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

    return GestureDetector(
      onDoubleTap: onReset ?? () => onChanged(defaultValue),
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
                Text(
                  '$valueText${unit ?? ''}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isModified ? const Color(0xFFFF8DA1) : Colors.white70,
                  ),
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
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
