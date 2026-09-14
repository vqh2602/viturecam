typedef FaceSettings = ReshapeSettings;

class ReshapeSettings {
  // Face
  final double slimFace; // 0..100
  final double smallFace; // 0..100
  final double vFace; // 0..100
  final double jawWidth; // -50..50 (0 default)
  final double cheekWidth; // -50..50
  final double chinLength; // -50..50
  final double chinWidth; // -50..50
  final double forehead; // -50..50
  final double templeWidth; // -50..50

  // Eyes
  final double eyeSize; // 0..100
  final double eyeWidth; // -50..50
  final double eyeHeight; // -50..50
  final double eyeDistance; // -50..50
  final double eyeAngle; // -50..50
  final double eyeBrightness; // 0..100

  // Nose
  final double noseWidth; // -50..50
  final double noseLength; // -50..50
  final double noseBridge; // -50..50
  final double noseTip; // -50..50
  final double nostrilWidth; // -50..50

  // Mouth
  final double mouthSize; // -50..50
  final double mouthWidth; // -50..50
  final double lipThickness; // -50..50
  final double smile; // 0..100
  final double smileCorners; // 0..100
  final double mouthPosition; // -50..50

  const ReshapeSettings({
    this.slimFace = 0,
    this.smallFace = 0,
    this.vFace = 0,
    this.jawWidth = 0,
    this.cheekWidth = 0,
    this.chinLength = 0,
    this.chinWidth = 0,
    this.forehead = 0,
    this.templeWidth = 0,
    this.eyeSize = 0,
    this.eyeWidth = 0,
    this.eyeHeight = 0,
    this.eyeDistance = 0,
    this.eyeAngle = 0,
    this.eyeBrightness = 0,
    this.noseWidth = 0,
    this.noseLength = 0,
    this.noseBridge = 0,
    this.noseTip = 0,
    this.nostrilWidth = 0,
    this.mouthSize = 0,
    this.mouthWidth = 0,
    this.lipThickness = 0,
    this.smile = 0,
    this.smileCorners = 0,
    this.mouthPosition = 0,
  });

  bool get isModified =>
      slimFace != 0 ||
      smallFace != 0 ||
      vFace != 0 ||
      jawWidth != 0 ||
      cheekWidth != 0 ||
      chinLength != 0 ||
      chinWidth != 0 ||
      forehead != 0 ||
      templeWidth != 0 ||
      eyeSize != 0 ||
      eyeWidth != 0 ||
      eyeHeight != 0 ||
      eyeDistance != 0 ||
      eyeAngle != 0 ||
      eyeBrightness != 0 ||
      noseWidth != 0 ||
      noseLength != 0 ||
      noseBridge != 0 ||
      noseTip != 0 ||
      nostrilWidth != 0 ||
      mouthSize != 0 ||
      mouthWidth != 0 ||
      lipThickness != 0 ||
      smile != 0 ||
      smileCorners != 0 ||
      mouthPosition != 0;

  bool isKeyActive(String key) {
    switch (key) {
      case 'slimFace':
        return slimFace != 0;
      case 'smallFace':
        return smallFace != 0;
      case 'vFace':
        return vFace != 0;
      case 'jawWidth':
        return jawWidth != 0;
      case 'cheekWidth':
        return cheekWidth != 0;
      case 'chinLength':
        return chinLength != 0;
      case 'chinWidth':
        return chinWidth != 0;
      case 'forehead':
        return forehead != 0;
      case 'templeWidth':
        return templeWidth != 0;
      case 'eyeSize':
        return eyeSize != 0;
      case 'eyeWidth':
        return eyeWidth != 0;
      case 'eyeHeight':
        return eyeHeight != 0;
      case 'eyeDistance':
        return eyeDistance != 0;
      case 'eyeAngle':
        return eyeAngle != 0;
      case 'eyeBrightness':
        return eyeBrightness != 0;
      case 'noseWidth':
        return noseWidth != 0;
      case 'noseLength':
        return noseLength != 0;
      case 'noseBridge':
        return noseBridge != 0;
      case 'noseTip':
        return noseTip != 0;
      case 'nostrilWidth':
        return nostrilWidth != 0;
      case 'mouthSize':
        return mouthSize != 0;
      case 'mouthWidth':
        return mouthWidth != 0;
      case 'lipThickness':
        return lipThickness != 0;
      case 'smile':
        return smile != 0;
      case 'smileCorners':
        return smileCorners != 0;
      case 'mouthPosition':
        return mouthPosition != 0;
      default:
        return false;
    }
  }

  ReshapeSettings copyWith({
    double? slimFace,
    double? smallFace,
    double? vFace,
    double? jawWidth,
    double? cheekWidth,
    double? chinLength,
    double? chinWidth,
    double? forehead,
    double? templeWidth,
    double? eyeSize,
    double? eyeWidth,
    double? eyeHeight,
    double? eyeDistance,
    double? eyeAngle,
    double? eyeBrightness,
    double? noseWidth,
    double? noseLength,
    double? noseBridge,
    double? noseTip,
    double? nostrilWidth,
    double? mouthSize,
    double? mouthWidth,
    double? lipThickness,
    double? smile,
    double? smileCorners,
    double? mouthPosition,
  }) {
    return ReshapeSettings(
      slimFace: slimFace ?? this.slimFace,
      smallFace: smallFace ?? this.smallFace,
      vFace: vFace ?? this.vFace,
      jawWidth: jawWidth ?? this.jawWidth,
      cheekWidth: cheekWidth ?? this.cheekWidth,
      chinLength: chinLength ?? this.chinLength,
      chinWidth: chinWidth ?? this.chinWidth,
      forehead: forehead ?? this.forehead,
      templeWidth: templeWidth ?? this.templeWidth,
      eyeSize: eyeSize ?? this.eyeSize,
      eyeWidth: eyeWidth ?? this.eyeWidth,
      eyeHeight: eyeHeight ?? this.eyeHeight,
      eyeDistance: eyeDistance ?? this.eyeDistance,
      eyeAngle: eyeAngle ?? this.eyeAngle,
      eyeBrightness: eyeBrightness ?? this.eyeBrightness,
      noseWidth: noseWidth ?? this.noseWidth,
      noseLength: noseLength ?? this.noseLength,
      noseBridge: noseBridge ?? this.noseBridge,
      noseTip: noseTip ?? this.noseTip,
      nostrilWidth: nostrilWidth ?? this.nostrilWidth,
      mouthSize: mouthSize ?? this.mouthSize,
      mouthWidth: mouthWidth ?? this.mouthWidth,
      lipThickness: lipThickness ?? this.lipThickness,
      smile: smile ?? this.smile,
      smileCorners: smileCorners ?? this.smileCorners,
      mouthPosition: mouthPosition ?? this.mouthPosition,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'slimFace': slimFace / 100.0,
      'smallFace': smallFace / 100.0,
      'vFace': vFace / 100.0,
      'jawWidth': jawWidth / 50.0,
      'cheekWidth': cheekWidth / 50.0,
      'chinLength': chinLength / 50.0,
      'chinWidth': chinWidth / 50.0,
      'forehead': forehead / 50.0,
      'templeWidth': templeWidth / 50.0,
      'eyeSize': eyeSize / 100.0,
      'eyeWidth': eyeWidth / 50.0,
      'eyeHeight': eyeHeight / 50.0,
      'eyeDistance': eyeDistance / 50.0,
      'eyeAngle': eyeAngle / 50.0,
      'eyeBrightness': eyeBrightness / 100.0,
      'noseWidth': noseWidth / 50.0,
      'noseLength': noseLength / 50.0,
      'noseBridge': noseBridge / 50.0,
      'noseTip': noseTip / 50.0,
      'nostrilWidth': nostrilWidth / 50.0,
      'mouthSize': mouthSize / 50.0,
      'mouthWidth': mouthWidth / 50.0,
      'lipThickness': lipThickness / 50.0,
      'smile': smile / 100.0,
      'smileCorners': smileCorners / 100.0,
      'mouthPosition': mouthPosition / 50.0,
    };
  }

  factory ReshapeSettings.fromJson(Map<String, dynamic> json) {
    return ReshapeSettings(
      slimFace: (json['slimFace'] as num?)?.toDouble() ?? 0,
      smallFace: (json['smallFace'] as num?)?.toDouble() ?? 0,
      vFace: (json['vFace'] as num?)?.toDouble() ?? 0,
      jawWidth: (json['jawWidth'] as num?)?.toDouble() ?? 0,
      cheekWidth: (json['cheekWidth'] as num?)?.toDouble() ?? 0,
      chinLength: (json['chinLength'] as num?)?.toDouble() ?? 0,
      chinWidth: (json['chinWidth'] as num?)?.toDouble() ?? 0,
      forehead: (json['forehead'] as num?)?.toDouble() ?? 0,
      templeWidth: (json['templeWidth'] as num?)?.toDouble() ?? 0,
      eyeSize: (json['eyeSize'] as num?)?.toDouble() ?? 0,
      eyeWidth: (json['eyeWidth'] as num?)?.toDouble() ?? 0,
      eyeHeight: (json['eyeHeight'] as num?)?.toDouble() ?? 0,
      eyeDistance: (json['eyeDistance'] as num?)?.toDouble() ?? 0,
      eyeAngle: (json['eyeAngle'] as num?)?.toDouble() ?? 0,
      eyeBrightness: (json['eyeBrightness'] as num?)?.toDouble() ?? 0,
      noseWidth: (json['noseWidth'] as num?)?.toDouble() ?? 0,
      noseLength: (json['noseLength'] as num?)?.toDouble() ?? 0,
      noseBridge: (json['noseBridge'] as num?)?.toDouble() ?? 0,
      noseTip: (json['noseTip'] as num?)?.toDouble() ?? 0,
      nostrilWidth: (json['nostrilWidth'] as num?)?.toDouble() ?? 0,
      mouthSize: (json['mouthSize'] as num?)?.toDouble() ?? 0,
      mouthWidth: (json['mouthWidth'] as num?)?.toDouble() ?? 0,
      lipThickness: (json['lipThickness'] as num?)?.toDouble() ?? 0,
      smile: (json['smile'] as num?)?.toDouble() ?? 0,
      smileCorners: (json['smileCorners'] as num?)?.toDouble() ?? 0,
      mouthPosition: (json['mouthPosition'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slimFace': slimFace,
      'smallFace': smallFace,
      'vFace': vFace,
      'jawWidth': jawWidth,
      'cheekWidth': cheekWidth,
      'chinLength': chinLength,
      'chinWidth': chinWidth,
      'forehead': forehead,
      'templeWidth': templeWidth,
      'eyeSize': eyeSize,
      'eyeWidth': eyeWidth,
      'eyeHeight': eyeHeight,
      'eyeDistance': eyeDistance,
      'eyeAngle': eyeAngle,
      'eyeBrightness': eyeBrightness,
      'noseWidth': noseWidth,
      'noseLength': noseLength,
      'noseBridge': noseBridge,
      'noseTip': noseTip,
      'nostrilWidth': nostrilWidth,
      'mouthSize': mouthSize,
      'mouthWidth': mouthWidth,
      'lipThickness': lipThickness,
      'smile': smile,
      'smileCorners': smileCorners,
      'mouthPosition': mouthPosition,
    };
  }
}
