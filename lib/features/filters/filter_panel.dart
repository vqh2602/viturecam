import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/beauty_slider.dart';
import '../camera/camera_controller.dart';
import 'filter_model.dart';

class FilterPanel extends ConsumerWidget {
  const FilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);
    final activeId = state.filterId;
    final intensity = state.filterIntensity;

    final activeItem = FilterCatalog.presets.firstWhere(
      (p) => p.id == activeId,
      orElse: () => FilterCatalog.presets.first,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Intensity Slider (or placeholder if original)
        SizedBox(
          height: 56,
          child: activeId != 'original'
              ? BeautySlider(
                  label: '${activeItem.name} Intensity',
                  value: intensity,
                  defaultValue: 80,
                  onChanged: (v) => controller.updateFilter(activeId, v),
                )
              : const Center(
                  child: Text(
                    'Original • Select a filter preset below',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
        ),

        const Divider(height: 1, color: Colors.white10),

        // Row 2: Filter Thumbnails Strip
        SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            itemCount: FilterCatalog.presets.length,
            itemBuilder: (context, idx) {
              final item = FilterCatalog.presets[idx];
              final isSel = item.id == activeId;

              return GestureDetector(
                onTap: () {
                  controller.updateFilter(
                    item.id,
                    item.id == 'original' ? 0 : (intensity == 0 ? item.defaultIntensity : intensity),
                  );
                },
                child: Container(
                  width: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 26,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            colors: item.gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: isSel ? const Color(0xFFFF7597) : Colors.white12,
                            width: isSel ? 2.0 : 1.0,
                          ),
                          boxShadow: isSel
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFFF7597).withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 1),
                                  )
                                ]
                              : null,
                        ),
                        child: isSel
                            ? const Center(
                                child: Icon(Icons.check, size: 14, color: Colors.white),
                              )
                            : null,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                          color: isSel ? Colors.white : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
