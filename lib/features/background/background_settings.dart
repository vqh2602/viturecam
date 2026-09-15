class BackgroundSettings {
  final String mode; // 'none', 'portrait_blur', 'strong_blur', 'virtual_studio', 'zoom_blur', 'swirly_bokeh', 'dreamy_blur', 'motion_blur'
  final double blurIntensity; // 0..100

  const BackgroundSettings({
    this.mode = 'none',
    this.blurIntensity = 50,
  });

  bool get isModified => mode != 'none';

  bool isKeyActive(String key) => mode == key;

  BackgroundSettings copyWith({
    String? mode,
    double? blurIntensity,
  }) {
    return BackgroundSettings(
      mode: mode ?? this.mode,
      blurIntensity: blurIntensity ?? this.blurIntensity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mode': mode,
      'blurIntensity': blurIntensity / 100.0,
    };
  }

  factory BackgroundSettings.fromJson(Map<String, dynamic> json) {
    return BackgroundSettings(
      mode: json['mode'] as String? ?? 'none',
      blurIntensity: (json['blurIntensity'] as num?)?.toDouble() ?? 50,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'blurIntensity': blurIntensity,
    };
  }
}
