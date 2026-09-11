import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'preset_model.dart';

class PresetStorage {
  static const String _fileName = 'user_presets.json';

  static Future<File> _getFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<List<PresetModel>> loadCustomPresets() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final List<dynamic> list = jsonDecode(content) as List<dynamic>;
      return list.map((item) => PresetModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[PresetStorage] Error loading custom presets: $e');
      return [];
    }
  }

  static Future<void> saveCustomPresets(List<PresetModel> presets) async {
    try {
      final file = await _getFile();
      final customOnly = presets.where((p) => !p.isBuiltIn).toList();
      final jsonList = customOnly.map((p) => p.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[PresetStorage] Error saving custom presets: $e');
    }
  }
}
