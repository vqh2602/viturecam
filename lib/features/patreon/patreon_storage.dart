import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'patreon_models.dart';

class PatreonStorage {
  static const String _accountFile = 'patreon_account.json';
  static const String _configFile = 'patreon_config.json';
  static Directory? customDirectory;

  static Future<File?> _getFile(String fileName) async {
    try {
      final dirPath = customDirectory?.path ?? (await getApplicationSupportDirectory()).path;
      return File('$dirPath/$fileName');
    } catch (e) {
      debugPrint('[PatreonStorage] Directory resolution error: $e');
      return null;
    }
  }

  static Future<PatreonAccount?> loadAccount() async {
    try {
      final file = await _getFile(_accountFile);
      if (file == null || !await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final json = jsonDecode(content) as Map<String, dynamic>;
      return PatreonAccount.fromJson(json);
    } catch (e) {
      debugPrint('[PatreonStorage] Error loading account: $e');
      return null;
    }
  }

  static Future<void> saveAccount(PatreonAccount? account) async {
    try {
      final file = await _getFile(_accountFile);
      if (file == null) return;
      if (account == null) {
        if (await file.exists()) {
          await file.delete();
        }
      } else {
        await file.writeAsString(jsonEncode(account.toJson()));
      }
    } catch (e) {
      debugPrint('[PatreonStorage] Error saving account: $e');
    }
  }

  static Future<PatreonConfig> loadConfig() async {
    try {
      final file = await _getFile(_configFile);
      if (file == null || !await file.exists()) return const PatreonConfig();
      final content = await file.readAsString();
      if (content.trim().isEmpty) return const PatreonConfig();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return PatreonConfig.fromJson(json);
    } catch (e) {
      debugPrint('[PatreonStorage] Error loading config: $e');
      return const PatreonConfig();
    }
  }

  static Future<void> saveConfig(PatreonConfig config) async {
    try {
      final file = await _getFile(_configFile);
      if (file == null) return;
      await file.writeAsString(jsonEncode(config.toJson()));
    } catch (e) {
      debugPrint('[PatreonStorage] Error saving config: $e');
    }
  }
}
