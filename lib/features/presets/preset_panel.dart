import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../camera/camera_controller.dart';

class PresetPanel extends ConsumerWidget {
  const PresetPanel({super.key});

  void _showSavePresetDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF222226),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Save Custom Preset',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Preset Name (e.g. My Glow)',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF2E2E34),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7597),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                ref.read(cameraControllerProvider.notifier).saveCurrentAsPreset(name);
                Navigator.of(dialogCtx).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);
    final presets = state.presets;
    final activeId = state.activePresetId;
    final activePreset = presets.where((p) => p.id == activeId).firstOrNull;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Active Preset Info + Save Current Button
        SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFFFF7597), size: 16),
                const SizedBox(width: 8),
                Text(
                  activePreset != null ? 'Active Preset: ${activePreset.name}' : 'Custom Settings Active',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28282E),
                    foregroundColor: const Color(0xFFFF8DA1),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFFFF7597), width: 0.8),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 14),
                  label: const Text('Save Current', style: TextStyle(fontSize: 11.5)),
                  onPressed: () => _showSavePresetDialog(context, ref),
                ),
              ],
            ),
          ),
        ),

        const Divider(height: 1, color: Colors.white10),

        // Row 2: Presets Cards Strip
        SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            itemCount: presets.length,
            itemBuilder: (context, idx) {
              final preset = presets[idx];
              final isSel = preset.id == activeId;

              return GestureDetector(
                onTap: () => controller.applyPreset(preset),
                child: Container(
                  width: 96,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF2E262A) : const Color(0xFF222227),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSel ? const Color(0xFFFF7597) : Colors.white12,
                      width: isSel ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        preset.isBuiltIn ? Icons.auto_awesome : Icons.person_outline,
                        size: 15,
                        color: isSel ? const Color(0xFFFF8DA1) : Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          preset.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                            color: isSel ? Colors.white : Colors.white70,
                          ),
                        ),
                      ),
                      if (!preset.isBuiltIn)
                        GestureDetector(
                          onTap: () => controller.deleteCustomPreset(preset.id),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 2),
                            child: Icon(Icons.close, size: 12, color: Colors.white54),
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
