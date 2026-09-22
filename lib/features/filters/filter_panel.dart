import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/beauty_slider.dart';
import '../camera/camera_controller.dart';
import 'filter_model.dart';

class FilterPanel extends ConsumerStatefulWidget {
  const FilterPanel({super.key});

  @override
  ConsumerState<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends ConsumerState<FilterPanel> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);
    final activeId = state.filterId;
    final intensity = state.filterIntensity;

    final categories = [
      {'id': 'All', 'label': l10n.filterCatAll},
      {'id': 'Douyin', 'label': l10n.filterCatDouyin},
      {'id': 'Natural', 'label': l10n.filterCatNatural},
      {'id': 'Korean', 'label': l10n.filterCatKorean},
      {'id': 'Film', 'label': l10n.filterCatFilm},
      {'id': 'Warm', 'label': l10n.filterCatWarm},
      {'id': 'Cool', 'label': l10n.filterCatCool},
      {'id': 'B&W', 'label': l10n.filterCatBW},
    ];

    final activeItem = FilterCatalog.presets.firstWhere(
      (p) => p.id == activeId,
      orElse: () => FilterCatalog.presets.first,
    );

    final displayPresets = _selectedCategory == 'All'
        ? FilterCatalog.presets
        : FilterCatalog.presets
            .where((p) => p.category == _selectedCategory || p.id == 'original')
            .toList();

    String getFilterDisplayName(FilterPreset item) {
      if (item.id == 'original') {
        return l10n.localeName.startsWith('vi') ? 'Gốc' : 'Original';
      }
      return item.name;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Category Chips + Active Intensity Slider
        SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 12),
              // Category filter pills
              SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      for (final cat in categories)
                        GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat['id']!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: _selectedCategory == cat['id'] ? const Color(0xFFFF7597) : const Color(0xFF222227),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedCategory == cat['id'] ? Colors.transparent : Colors.white10,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                cat['label']!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: _selectedCategory == cat['id'] ? FontWeight.w600 : FontWeight.w400,
                                  color: _selectedCategory == cat['id'] ? Colors.white : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const VerticalDivider(width: 1, indent: 12, endIndent: 12, color: Colors.white10),
              const SizedBox(width: 6),
              // Slider or placeholder
              Expanded(
                child: activeId != 'original'
                    ? Row(
                        children: [
                          Expanded(
                            child: BeautySlider(
                              label: l10n.filterIntensity(getFilterDisplayName(activeItem)),
                              value: intensity,
                              defaultValue: 80,
                              onChanged: (v) => controller.updateFilter(activeId, v),
                            ),
                          ),
                          if (activeItem.isLut) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF818CF8).withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.palette_outlined, size: 11, color: Color(0xFFA5B4FC)),
                                  SizedBox(width: 3),
                                  Text(
                                    '3D LUT',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFA5B4FC),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      )
                    : Center(
                        child: Text(
                          l10n.filterOriginalPlaceholder,
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Colors.white10),

        // Row 2: Filter Thumbnails Strip
        SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            itemCount: displayPresets.length,
            itemBuilder: (context, idx) {
              final item = displayPresets[idx];
              final isSel = item.id == activeId;
              final displayName = getFilterDisplayName(item);

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
                        displayName,
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
