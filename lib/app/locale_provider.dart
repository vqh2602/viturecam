import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App locale provider.
///
/// When `null`, Flutter automatically resolves the locale matching the
/// host machine / device system language (defaults to Vietnamese if device
/// is in Vietnamese, English if device is in English, or English fallback).
///
/// Users can also explicitly override it in Settings to Vietnamese or English.
final appLocaleProvider = StateProvider<Locale?>((ref) => null);
