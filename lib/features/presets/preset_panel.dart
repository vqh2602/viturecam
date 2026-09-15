import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../camera/camera_controller.dart';
import 'preset_model.dart';

class PresetPanel extends ConsumerWidget {
  const PresetPanel({super.key});

  static String getPresetDisplayName(AppLocalizations l10n, PresetModel preset) {
    if (!preset.isBuiltIn) return preset.name;
    final isVi = l10n.localeName.startsWith('vi');
    switch (preset.id) {
      case 'natural':
        return isVi ? 'Tự nhiên' : 'Natural';
      case 'soft':
        return isVi ? 'Nhẹ nhàng' : 'Soft';
      case 'korean':
        return isVi ? 'Hàn Quốc' : 'Korean';
      case 'clean':
        return isVi ? 'Thanh lịch' : 'Clean';
      case 'glamour':
        return isVi ? 'Quyến rũ' : 'Glamour';
      case 'fresh':
        return isVi ? 'Tươi tắn' : 'Fresh';
      default:
        return preset.name;
    }
  }

  void _showSavePresetDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF222226),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.saveCustomPreset,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: l10n.presetNameHint,
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
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
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
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
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
                  activePreset != null
                      ? l10n.activePreset(getPresetDisplayName(l10n, activePreset))
                      : l10n.customSettingsActive,
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
                  label: Text(l10n.saveCurrent, style: const TextStyle(fontSize: 11.5)),
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
              final displayName = getPresetDisplayName(l10n, preset);

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
                          displayName,
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
