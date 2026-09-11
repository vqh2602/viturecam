import 'package:flutter/material.dart';

class MakeupOption {
  final String id;
  final String name;
  final Color color;

  const MakeupOption({
    required this.id,
    required this.name,
    required this.color,
  });
}

class MakeupPresets {
  static const List<MakeupOption> lipOptions = [
    MakeupOption(id: 'none', name: 'None', color: Colors.transparent),
    MakeupOption(id: 'nude', name: 'Nude', color: Color(0xFFC48B71)),
    MakeupOption(id: 'rose', name: 'Rose', color: Color(0xFFC75B7A)),
    MakeupOption(id: 'coral', name: 'Coral', color: Color(0xFFE06D53)),
    MakeupOption(id: 'red', name: 'Red', color: Color(0xFFBF2638)),
    MakeupOption(id: 'berry', name: 'Berry', color: Color(0xFF8C2D40)),
    MakeupOption(id: 'pink', name: 'Pink', color: Color(0xFFE87E98)),
    MakeupOption(id: 'brown', name: 'Brown', color: Color(0xFF824739)),
  ];

  static const List<MakeupOption> blushOptions = [
    MakeupOption(id: 'none', name: 'None', color: Colors.transparent),
    MakeupOption(id: 'rosy', name: 'Rosy', color: Color(0xFFFF9AA2)),
    MakeupOption(id: 'peach', name: 'Peach', color: Color(0xFFFFB7B2)),
    MakeupOption(id: 'coral', name: 'Coral', color: Color(0xFFFFDAC1)),
    MakeupOption(id: 'mauve', name: 'Mauve', color: Color(0xFFE2B6CF)),
  ];

  static const List<MakeupOption> eyebrowOptions = [
    MakeupOption(id: 'none', name: 'None', color: Colors.transparent),
    MakeupOption(id: 'natural', name: 'Natural', color: Color(0xFF5A463B)),
    MakeupOption(id: 'soft', name: 'Soft Gray', color: Color(0xFF424242)),
    MakeupOption(id: 'brown', name: 'Chestnut', color: Color(0xFF3E2723)),
  ];

  static const List<MakeupOption> eyelinerOptions = [
    MakeupOption(id: 'none', name: 'None', color: Colors.transparent),
    MakeupOption(id: 'classic', name: 'Classic', color: Color(0xFF212121)),
    MakeupOption(id: 'cat', name: 'Cat Eye', color: Color(0xFF1A1A1A)),
    MakeupOption(id: 'brown', name: 'Deep Brown', color: Color(0xFF3B2F2F)),
  ];

  static const List<MakeupOption> eyeshadowOptions = [
    MakeupOption(id: 'none', name: 'None', color: Colors.transparent),
    MakeupOption(id: 'earth', name: 'Earth', color: Color(0xFFA1887F)),
    MakeupOption(id: 'sunset', name: 'Sunset', color: Color(0xFFFF8A65)),
    MakeupOption(id: 'pink', name: 'Pink Shimmer', color: Color(0xFFF48FB1)),
    MakeupOption(id: 'smoky', name: 'Smoky', color: Color(0xFF616161)),
  ];
}

class MakeupSettings {
  final String lipPreset;
  final double lipOpacity; // 0..100
  final String blushPreset;
  final double blushOpacity; // 0..100
  final String eyebrowPreset;
  final double eyebrowOpacity; // 0..100
  final String eyelinerPreset;
  final double eyelinerOpacity; // 0..100
  final String eyeshadowPreset;
  final double eyeshadowOpacity; // 0..100

  const MakeupSettings({
    this.lipPreset = 'none',
    this.lipOpacity = 60,
    this.blushPreset = 'none',
    this.blushOpacity = 50,
    this.eyebrowPreset = 'none',
    this.eyebrowOpacity = 50,
    this.eyelinerPreset = 'none',
    this.eyelinerOpacity = 60,
    this.eyeshadowPreset = 'none',
    this.eyeshadowOpacity = 50,
  });

  bool get isModified =>
      (lipPreset != 'none' && lipOpacity > 0) ||
      (blushPreset != 'none' && blushOpacity > 0) ||
      (eyebrowPreset != 'none' && eyebrowOpacity > 0) ||
      (eyelinerPreset != 'none' && eyelinerOpacity > 0) ||
      (eyeshadowPreset != 'none' && eyeshadowOpacity > 0);

  bool isKeyActive(String key) {
    switch (key) {
      case 'lip':
        return lipPreset != 'none' && lipOpacity > 0;
      case 'blush':
        return blushPreset != 'none' && blushOpacity > 0;
      case 'eyebrow':
        return eyebrowPreset != 'none' && eyebrowOpacity > 0;
      case 'eyeliner':
        return eyelinerPreset != 'none' && eyelinerOpacity > 0;
      case 'eyeshadow':
        return eyeshadowPreset != 'none' && eyeshadowOpacity > 0;
      default:
        return false;
    }
  }

  MakeupSettings copyWith({
    String? lipPreset,
    double? lipOpacity,
    String? blushPreset,
    double? blushOpacity,
    String? eyebrowPreset,
    double? eyebrowOpacity,
    String? eyelinerPreset,
    double? eyelinerOpacity,
    String? eyeshadowPreset,
    double? eyeshadowOpacity,
  }) {
    return MakeupSettings(
      lipPreset: lipPreset ?? this.lipPreset,
      lipOpacity: lipOpacity ?? this.lipOpacity,
      blushPreset: blushPreset ?? this.blushPreset,
      blushOpacity: blushOpacity ?? this.blushOpacity,
      eyebrowPreset: eyebrowPreset ?? this.eyebrowPreset,
      eyebrowOpacity: eyebrowOpacity ?? this.eyebrowOpacity,
      eyelinerPreset: eyelinerPreset ?? this.eyelinerPreset,
      eyelinerOpacity: eyelinerOpacity ?? this.eyelinerOpacity,
      eyeshadowPreset: eyeshadowPreset ?? this.eyeshadowPreset,
      eyeshadowOpacity: eyeshadowOpacity ?? this.eyeshadowOpacity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lipPreset': lipPreset,
      'lipOpacity': lipOpacity / 100.0,
      'blushPreset': blushPreset,
      'blushOpacity': blushOpacity / 100.0,
      'eyebrowPreset': eyebrowPreset,
      'eyebrowOpacity': eyebrowOpacity / 100.0,
      'eyelinerPreset': eyelinerPreset,
      'eyelinerOpacity': eyelinerOpacity / 100.0,
      'eyeshadowPreset': eyeshadowPreset,
      'eyeshadowOpacity': eyeshadowOpacity / 100.0,
    };
  }

  factory MakeupSettings.fromJson(Map<String, dynamic> json) {
    return MakeupSettings(
      lipPreset: json['lipPreset'] as String? ?? 'none',
      lipOpacity: (json['lipOpacity'] as num?)?.toDouble() ?? 60,
      blushPreset: json['blushPreset'] as String? ?? 'none',
      blushOpacity: (json['blushOpacity'] as num?)?.toDouble() ?? 50,
      eyebrowPreset: json['eyebrowPreset'] as String? ?? 'none',
      eyebrowOpacity: (json['eyebrowOpacity'] as num?)?.toDouble() ?? 50,
      eyelinerPreset: json['eyelinerPreset'] as String? ?? 'none',
      eyelinerOpacity: (json['eyelinerOpacity'] as num?)?.toDouble() ?? 60,
      eyeshadowPreset: json['eyeshadowPreset'] as String? ?? 'none',
      eyeshadowOpacity: (json['eyeshadowOpacity'] as num?)?.toDouble() ?? 50,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lipPreset': lipPreset,
      'lipOpacity': lipOpacity,
      'blushPreset': blushPreset,
      'blushOpacity': blushOpacity,
      'eyebrowPreset': eyebrowPreset,
      'eyebrowOpacity': eyebrowOpacity,
      'eyelinerPreset': eyelinerPreset,
      'eyelinerOpacity': eyelinerOpacity,
      'eyeshadowPreset': eyeshadowPreset,
      'eyeshadowOpacity': eyeshadowOpacity,
    };
  }
}
