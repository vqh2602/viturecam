class BeautySettings {
  final double smooth; // 0..100
  final double skinTexture; // 0..100
  final double skinBrightness; // 0..100
  final double whitening; // 0..100
  final double redness; // 0..100
  final double darkCircle; // 0..100
  final double eyeBag; // 0..100
  final double teethWhitening; // 0..100

  const BeautySettings({
    this.smooth = 0,
    this.skinTexture = 50,
    this.skinBrightness = 0,
    this.whitening = 0,
    this.redness = 0,
    this.darkCircle = 0,
    this.eyeBag = 0,
    this.teethWhitening = 0,
  });

  bool get isModified =>
      smooth > 0 ||
      skinTexture != 50 ||
      skinBrightness > 0 ||
      whitening > 0 ||
      redness > 0 ||
      darkCircle > 0 ||
      eyeBag > 0 ||
      teethWhitening > 0;

  bool isKeyActive(String key) {
    switch (key) {
      case 'smooth':
        return smooth > 0;
      case 'skinTexture':
        return skinTexture != 50;
      case 'skinBrightness':
        return skinBrightness > 0;
      case 'whitening':
        return whitening > 0;
      case 'redness':
        return redness > 0;
      case 'darkCircle':
        return darkCircle > 0;
      case 'eyeBag':
        return eyeBag > 0;
      case 'teethWhitening':
        return teethWhitening > 0;
      default:
        return false;
    }
  }

  BeautySettings copyWith({
    double? smooth,
    double? skinTexture,
    double? skinBrightness,
    double? whitening,
    double? redness,
    double? darkCircle,
    double? eyeBag,
    double? teethWhitening,
  }) {
    return BeautySettings(
      smooth: smooth ?? this.smooth,
      skinTexture: skinTexture ?? this.skinTexture,
      skinBrightness: skinBrightness ?? this.skinBrightness,
      whitening: whitening ?? this.whitening,
      redness: redness ?? this.redness,
      darkCircle: darkCircle ?? this.darkCircle,
      eyeBag: eyeBag ?? this.eyeBag,
      teethWhitening: teethWhitening ?? this.teethWhitening,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'smooth': smooth / 100.0,
      'skinTexture': skinTexture / 100.0,
      'skinBrightness': skinBrightness / 100.0,
      'whitening': whitening / 100.0,
      'redness': redness / 100.0,
      'darkCircle': darkCircle / 100.0,
      'eyeBag': eyeBag / 100.0,
      'teethWhitening': teethWhitening / 100.0,
    };
  }

  factory BeautySettings.fromJson(Map<String, dynamic> json) {
    return BeautySettings(
      smooth: (json['smooth'] as num?)?.toDouble() ?? 0,
      skinTexture: (json['skinTexture'] as num?)?.toDouble() ?? 50,
      skinBrightness: (json['skinBrightness'] as num?)?.toDouble() ?? 0,
      whitening: (json['whitening'] as num?)?.toDouble() ?? 0,
      redness: (json['redness'] as num?)?.toDouble() ?? 0,
      darkCircle: (json['darkCircle'] as num?)?.toDouble() ?? 0,
      eyeBag: (json['eyeBag'] as num?)?.toDouble() ?? 0,
      teethWhitening: (json['teethWhitening'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'smooth': smooth,
      'skinTexture': skinTexture,
      'skinBrightness': skinBrightness,
      'whitening': whitening,
      'redness': redness,
      'darkCircle': darkCircle,
      'eyeBag': eyeBag,
      'teethWhitening': teethWhitening,
    };
  }
}
