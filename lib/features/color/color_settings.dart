class ColorSettings {
  final double exposure; // -100..100 (default 0)
  final double brightness; // -100..100 (default 0)
  final double contrast; // -100..100 (default 0 -> 1.0)
  final double highlights; // -100..100 (default 0)
  final double shadows; // -100..100 (default 0)
  final double saturation; // -100..100 (default 0 -> 1.0)
  final double temperature; // -100..100 (default 0)
  final double tint; // -100..100 (default 0)
  final double sharpness; // 0..100 (default 0)

  const ColorSettings({
    this.exposure = 0,
    this.brightness = 0,
    this.contrast = 0,
    this.highlights = 0,
    this.shadows = 0,
    this.saturation = 0,
    this.temperature = 0,
    this.tint = 0,
    this.sharpness = 0,
  });

  bool get isModified =>
      exposure != 0 ||
      brightness != 0 ||
      contrast != 0 ||
      highlights != 0 ||
      shadows != 0 ||
      saturation != 0 ||
      temperature != 0 ||
      tint != 0 ||
      sharpness != 0;

  bool isKeyActive(String key) {
    switch (key) {
      case 'exposure':
        return exposure != 0;
      case 'brightness':
        return brightness != 0;
      case 'contrast':
        return contrast != 0;
      case 'highlights':
        return highlights != 0;
      case 'shadows':
        return shadows != 0;
      case 'saturation':
        return saturation != 0;
      case 'temperature':
        return temperature != 0;
      case 'tint':
        return tint != 0;
      case 'sharpness':
        return sharpness != 0;
      default:
        return false;
    }
  }

  ColorSettings copyWith({
    double? exposure,
    double? brightness,
    double? contrast,
    double? highlights,
    double? shadows,
    double? saturation,
    double? temperature,
    double? tint,
    double? sharpness,
  }) {
    return ColorSettings(
      exposure: exposure ?? this.exposure,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      highlights: highlights ?? this.highlights,
      shadows: shadows ?? this.shadows,
      saturation: saturation ?? this.saturation,
      temperature: temperature ?? this.temperature,
      tint: tint ?? this.tint,
      sharpness: sharpness ?? this.sharpness,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'exposure': exposure / 100.0,
      'brightness': brightness / 100.0,
      'contrast': 1.0 + (contrast / 100.0) * 0.5,
      'highlights': highlights / 100.0,
      'shadows': shadows / 100.0,
      'saturation': 1.0 + (saturation / 100.0),
      'temperature': temperature / 100.0,
      'tint': tint / 100.0,
      'sharpness': sharpness / 100.0,
    };
  }

  factory ColorSettings.fromJson(Map<String, dynamic> json) {
    return ColorSettings(
      exposure: (json['exposure'] as num?)?.toDouble() ?? 0,
      brightness: (json['brightness'] as num?)?.toDouble() ?? 0,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 0,
      highlights: (json['highlights'] as num?)?.toDouble() ?? 0,
      shadows: (json['shadows'] as num?)?.toDouble() ?? 0,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
      tint: (json['tint'] as num?)?.toDouble() ?? 0,
      sharpness: (json['sharpness'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exposure': exposure,
      'brightness': brightness,
      'contrast': contrast,
      'highlights': highlights,
      'shadows': shadows,
      'saturation': saturation,
      'temperature': temperature,
      'tint': tint,
      'sharpness': sharpness,
    };
  }
}
