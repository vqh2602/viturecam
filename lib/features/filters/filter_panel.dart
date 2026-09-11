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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Filter Thumbnails Strip
        SizedBox(
          height: 86,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  width: 60,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: item.gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: isSel ? const Color(0xFFFF7597) : Colors.transparent,
                            width: 2.2,
                          ),
                          boxShadow: isSel
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFFF7597).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: isSel
                            ? const Center(
                                child: Icon(Icons.check, size: 18, color: Colors.white),
                              )
                            : null,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
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

        // Intensity Slider (if filter selected)
        if (activeId != 'original')
          BeautySlider(
            label: 'Filter Intensity',
            value: intensity,
            defaultValue: 80,
            onChanged: (v) => controller.updateFilter(activeId, v),
          )
        else
          const SizedBox(height: 12),
      ],
    );
  }
}
