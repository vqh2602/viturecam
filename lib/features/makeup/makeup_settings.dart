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

class MakeupStyleOption {
  final String id;
  final String name;
  final IconData icon;

  const MakeupStyleOption({
    required this.id,
    required this.name,
    required this.icon,
  });
}

class MakeupPresets {
  static const List<MakeupOption> lipOptions = [
    MakeupOption(id: 'none', name: 'None', color: Colors.transparent),
    MakeupOption(id: 'red', name: 'Đỏ thuần', color: Color(0xFFBF2638)),
    MakeupOption(id: 'ruby', name: 'Đỏ ruby', color: Color(0xFF9E1B32)),
    MakeupOption(id: 'chili', name: 'Đỏ đất', color: Color(0xFFA83E2C)),
    MakeupOption(id: 'cherry', name: 'Đỏ cherry', color: Color(0xFF8F1D35)),
    MakeupOption(id: 'wine', name: 'Rượu vang', color: Color(0xFF6A1B29)),
    MakeupOption(id: 'coral', name: 'San hô', color: Color(0xFFE06D53)),
    MakeupOption(id: 'orange', name: 'Cam cháy', color: Color(0xFFC85A32)),
    MakeupOption(id: 'peach', name: 'Hồng đào', color: Color(0xFFEB8676)),
    MakeupOption(id: 'rose', name: 'Hồng đất', color: Color(0xFFC75B7A)),
    MakeupOption(id: 'pink', name: 'Hồng phấn', color: Color(0xFFE87E98)),
    MakeupOption(id: 'nude', name: 'Cam nude', color: Color(0xFFC48B71)),
    MakeupOption(id: 'nudePink', name: 'Hồng nude', color: Color(0xFFD49B9B)),
    MakeupOption(id: 'berry', name: 'Berry', color: Color(0xFF8C2D40)),
    MakeupOption(id: 'plum', name: 'Mận chín', color: Color(0xFF682845)),
    MakeupOption(id: 'brown', name: 'Nâu quế', color: Color(0xFF824739)),
    MakeupOption(id: 'caramel', name: 'Caramel', color: Color(0xFFA55A38)),
  ];

  static const List<MakeupStyleOption> lipStyles = [
    MakeupStyleOption(id: 'full', name: 'Full môi', icon: Icons.brush),
    MakeupStyleOption(id: 'gradient', name: 'Lòng môi', icon: Icons.gradient),
    MakeupStyleOption(id: 'liner', name: 'Viền môi', icon: Icons.crop_free),
    MakeupStyleOption(id: 'gloss', name: 'Son bóng', icon: Icons.auto_awesome),
  ];

  static const List<MakeupOption> blushOptions = [
    MakeupOption(id: 'none', name: 'None', color: Colors.transparent),
    MakeupOption(id: 'rosy', name: 'Hồng tự nhiên', color: Color(0xFFFF9AA2)),
    MakeupOption(id: 'peach', name: 'Cam đào', color: Color(0xFFFFB7B2)),
    MakeupOption(id: 'coral', name: 'San hô tươi', color: Color(0xFFFFAAA6)),
    MakeupOption(id: 'apricot', name: 'Mơ chín', color: Color(0xFFFFC8A2)),
    MakeupOption(id: 'strawberry', name: 'Dâu tây', color: Color(0xFFFF6B8B)),
    MakeupOption(id: 'mauve', name: 'Cánh hồng khô', color: Color(0xFFE2B6CF)),
    MakeupOption(id: 'terracotta', name: 'Cam đất', color: Color(0xFFD97D64)),
    MakeupOption(id: 'plum', name: 'Mận dịu', color: Color(0xFFC27BA0)),
    MakeupOption(id: 'cherry', name: 'Đỏ cherry', color: Color(0xFFE05A6D)),
  ];

  static const List<MakeupStyleOption> blushStyles = [
    MakeupStyleOption(id: 'apple', name: 'Gò má tròn', icon: Icons.circle_outlined),
    MakeupStyleOption(id: 'sunkissed', name: 'Say rượu', icon: Icons.wb_sunny_outlined),
    MakeupStyleOption(id: 'lifted', name: 'Kéo thái dương', icon: Icons.trending_up),
    MakeupStyleOption(id: 'undereye', name: 'Dưới mắt', icon: Icons.remove_red_eye_outlined),
    MakeupStyleOption(id: 'contour', name: 'Tạo khối', icon: Icons.filter_hdr),
  ];

  static const List<MakeupStyleOption> femaleEyebrowStyles = [
    MakeupStyleOption(id: 'natural', name: 'Tự nhiên', icon: Icons.auto_awesome),
    MakeupStyleOption(id: 'korean', name: 'Ngang Hàn', icon: Icons.horizontal_rule),
    MakeupStyleOption(id: 'arched', name: 'Cánh cung', icon: Icons.show_chart),
    MakeupStyleOption(id: 'feathered', name: 'Phẩy sợi', icon: Icons.grain),
    MakeupStyleOption(id: 'willow', name: 'Lá liễu', icon: Icons.spa_outlined),
  ];

  static const List<MakeupStyleOption> maleEyebrowStyles = [
    MakeupStyleOption(id: 'male_natural', name: 'Nam tự nhiên', icon: Icons.face),
    MakeupStyleOption(id: 'male_sword', name: 'Dáng kiếm', icon: Icons.trending_up),
    MakeupStyleOption(id: 'male_bold', name: 'Ngang rậm', icon: Icons.line_weight),
    MakeupStyleOption(id: 'male_feathered', name: 'Phẩy sợi nam', icon: Icons.grain),
  ];

  static const List<MakeupStyleOption> eyebrowStyles = [
    ...femaleEyebrowStyles,
    ...maleEyebrowStyles,
  ];

  static bool isMaleEyebrow(String style) => style.startsWith('male_');

  static const List<MakeupOption> eyebrowOptions = [
    MakeupOption(id: 'none', name: 'None', color: Colors.transparent),
    MakeupOption(id: 'black', name: 'Đen tự nhiên', color: Color(0xFF222222)),
    MakeupOption(id: 'darkBrown', name: 'Nâu đen', color: Color(0xFF3D2B1F)),
    MakeupOption(id: 'natural', name: 'Nâu tự nhiên', color: Color(0xFF5A463B)),
    MakeupOption(id: 'chestnut', name: 'Hạt dẻ', color: Color(0xFF4E3629)),
    MakeupOption(id: 'ashBrown', name: 'Nâu khói', color: Color(0xFF5C5248)),
    MakeupOption(id: 'soft', name: 'Xám khói', color: Color(0xFF424242)),
    MakeupOption(id: 'blonde', name: 'Nâu sáng', color: Color(0xFF7D6752)),
    MakeupOption(id: 'redBrown', name: 'Nâu đỏ', color: Color(0xFF5C3328)),
  ];

  static const List<MakeupStyleOption> eyelinerStyles = [
    MakeupStyleOption(id: 'natural', name: 'Mí trong', icon: Icons.remove),
    MakeupStyleOption(id: 'classic', name: 'Đuôi mảnh', icon: Icons.trending_flat),
    MakeupStyleOption(id: 'cat', name: 'Mắt mèo', icon: Icons.north_east),
    MakeupStyleOption(id: 'puppy', name: 'Mắt cún', icon: Icons.south_east),
    MakeupStyleOption(id: 'fox', name: 'Mắt cáo', icon: Icons.visibility),
  ];

  static const List<MakeupOption> eyelinerOptions = [
    MakeupOption(id: 'none', name: 'None', color: Colors.transparent),
    MakeupOption(id: 'black', name: 'Đen tuyền', color: Color(0xFF141414)),
    MakeupOption(id: 'classic', name: 'Đen mềm', color: Color(0xFF262626)),
    MakeupOption(id: 'deepBrown', name: 'Nâu đậm', color: Color(0xFF38261F)),
    MakeupOption(id: 'brown', name: 'Nâu cà phê', color: Color(0xFF4A342B)),
    MakeupOption(id: 'burgundy', name: 'Đỏ rượu', color: Color(0xFF581D22)),
    MakeupOption(id: 'plum', name: 'Mận sâu', color: Color(0xFF432338)),
    MakeupOption(id: 'navy', name: 'Xanh navy', color: Color(0xFF1A2634)),
    MakeupOption(id: 'white', name: 'Trắng viền', color: Color(0xFFE8E8E8)),
  ];

  static const List<MakeupStyleOption> eyeshadowStyles = [
    MakeupStyleOption(id: 'gradient', name: 'Tán đều', icon: Icons.gradient),
    MakeupStyleOption(id: 'halo', name: 'Tâm sáng', icon: Icons.wb_sunny_outlined),
    MakeupStyleOption(id: 'cutCrease', name: 'Cắt mí', icon: Icons.content_cut),
    MakeupStyleOption(id: 'outerV', name: 'Đuôi V', icon: Icons.change_history),
    MakeupStyleOption(id: 'douyin', name: 'Douyin', icon: Icons.star_border),
  ];

  static const List<MakeupOption> eyeshadowOptions = [
    MakeupOption(id: 'none', name: 'None', color: Colors.transparent),
    MakeupOption(id: 'earth', name: 'Nâu đất', color: Color(0xFFA1887F)),
    MakeupOption(id: 'peach', name: 'Cam đào', color: Color(0xFFF4A261)),
    MakeupOption(id: 'sunset', name: 'Hoàng hôn', color: Color(0xFFFF8A65)),
    MakeupOption(id: 'rose', name: 'Hồng đất', color: Color(0xFFC75B7A)),
    MakeupOption(id: 'pink', name: 'Hồng phấn', color: Color(0xFFF48FB1)),
    MakeupOption(id: 'coral', name: 'San hô', color: Color(0xFFE06D53)),
    MakeupOption(id: 'mauve', name: 'Tím khói', color: Color(0xFF9E7B8E)),
    MakeupOption(id: 'champagne', name: 'Sâm banh', color: Color(0xFFE8C8A9)),
    MakeupOption(id: 'smoky', name: 'Khói đen', color: Color(0xFF505050)),
  ];
  static const List<MakeupStyleOption> contourStyles = [
    MakeupStyleOption(id: 'vShape', name: 'Mặt V-Line', icon: Icons.change_history),
    MakeupStyleOption(id: 'natural', name: 'Tự nhiên', icon: Icons.auto_awesome),
    MakeupStyleOption(id: 'sculpted', name: '3D sắc sảo', icon: Icons.layers),
    MakeupStyleOption(id: 'nose', name: 'Thon gọn mũi', icon: Icons.tune),
    MakeupStyleOption(id: 'soft', name: 'Mềm mại', icon: Icons.blur_on),
  ];

  static const List<MakeupOption> contourOptions = [
    MakeupOption(id: 'none', name: 'None', color: Colors.transparent),
    MakeupOption(id: 'natural', name: 'Nâu tự nhiên', color: Color(0xFF947561)),
    MakeupOption(id: 'warm', name: 'Nâu ấm', color: Color(0xFF9E7052)),
    MakeupOption(id: 'cool', name: 'Nâu lạnh khói', color: Color(0xFF857066)),
    MakeupOption(id: 'bronze', name: 'Nâu đồng', color: Color(0xFFAF7A4D)),
    MakeupOption(id: 'caramel', name: 'Caramel', color: Color(0xFFA67347)),
    MakeupOption(id: 'deep', name: 'Nâu đậm', color: Color(0xFF73523D)),
    MakeupOption(id: 'softTaupe', name: 'Nâu khói nhạt', color: Color(0xFF8C7A6B)),
  ];
}

class MakeupSettings {
  final String lipPreset;
  final double lipOpacity; // 0..100
  final String lipStyle;   // 'full', 'gradient', 'liner', 'gloss'

  final String blushPreset;
  final double blushOpacity; // 0..100
  final String blushStyle;   // 'apple', 'sunkissed', 'lifted', 'undereye', 'contour'

  final String eyebrowPreset;
  final double eyebrowOpacity; // 0..100
  final String eyebrowStyle;   // 'natural', 'korean', 'arched', 'feathered', 'willow'

  final String eyelinerPreset;
  final double eyelinerOpacity; // 0..100
  final String eyelinerStyle;  // 'natural', 'classic', 'cat', 'puppy', 'fox'

  final String eyeshadowPreset;
  final double eyeshadowOpacity; // 0..100
  final String eyeshadowStyle; // 'gradient', 'halo', 'cutCrease', 'outerV', 'douyin'

  final String contourPreset;
  final double contourOpacity; // 0..100
  final String contourStyle;   // 'vShape', 'natural', 'sculpted', 'nose', 'soft'

  const MakeupSettings({
    this.lipPreset = 'none',
    this.lipOpacity = 60,
    this.lipStyle = 'full',
    this.blushPreset = 'none',
    this.blushOpacity = 50,
    this.blushStyle = 'apple',
    this.eyebrowPreset = 'none',
    this.eyebrowOpacity = 50,
    this.eyebrowStyle = 'natural',
    this.eyelinerPreset = 'none',
    this.eyelinerOpacity = 60,
    this.eyelinerStyle = 'classic',
    this.eyeshadowPreset = 'none',
    this.eyeshadowOpacity = 50,
    this.eyeshadowStyle = 'gradient',
    this.contourPreset = 'none',
    this.contourOpacity = 50,
    this.contourStyle = 'vShape',
  });

  bool get isModified =>
      (lipPreset != 'none' && lipOpacity > 0) ||
      (blushPreset != 'none' && blushOpacity > 0) ||
      (eyebrowPreset != 'none' && eyebrowOpacity > 0) ||
      (eyelinerPreset != 'none' && eyelinerOpacity > 0) ||
      (eyeshadowPreset != 'none' && eyeshadowOpacity > 0) ||
      (contourPreset != 'none' && contourOpacity > 0);

  bool get hasLip => lipPreset != 'none' && lipOpacity > 0;
  bool get hasBlush => blushPreset != 'none' && blushOpacity > 0;
  bool get hasContour => contourPreset != 'none' && contourOpacity > 0;

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
      case 'contour':
        return contourPreset != 'none' && contourOpacity > 0;
      default:
        return false;
    }
  }

  MakeupSettings copyWith({
    String? lipPreset,
    double? lipOpacity,
    String? lipStyle,
    String? blushPreset,
    double? blushOpacity,
    String? blushStyle,
    String? eyebrowPreset,
    double? eyebrowOpacity,
    String? eyebrowStyle,
    String? eyelinerPreset,
    double? eyelinerOpacity,
    String? eyelinerStyle,
    String? eyeshadowPreset,
    double? eyeshadowOpacity,
    String? eyeshadowStyle,
    String? contourPreset,
    double? contourOpacity,
    String? contourStyle,
  }) {
    return MakeupSettings(
      lipPreset: lipPreset ?? this.lipPreset,
      lipOpacity: lipOpacity ?? this.lipOpacity,
      lipStyle: lipStyle ?? this.lipStyle,
      blushPreset: blushPreset ?? this.blushPreset,
      blushOpacity: blushOpacity ?? this.blushOpacity,
      blushStyle: blushStyle ?? this.blushStyle,
      eyebrowPreset: eyebrowPreset ?? this.eyebrowPreset,
      eyebrowOpacity: eyebrowOpacity ?? this.eyebrowOpacity,
      eyebrowStyle: eyebrowStyle ?? this.eyebrowStyle,
      eyelinerPreset: eyelinerPreset ?? this.eyelinerPreset,
      eyelinerOpacity: eyelinerOpacity ?? this.eyelinerOpacity,
      eyelinerStyle: eyelinerStyle ?? this.eyelinerStyle,
      eyeshadowPreset: eyeshadowPreset ?? this.eyeshadowPreset,
      eyeshadowOpacity: eyeshadowOpacity ?? this.eyeshadowOpacity,
      eyeshadowStyle: eyeshadowStyle ?? this.eyeshadowStyle,
      contourPreset: contourPreset ?? this.contourPreset,
      contourOpacity: contourOpacity ?? this.contourOpacity,
      contourStyle: contourStyle ?? this.contourStyle,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lipPreset': lipPreset,
      'lipOpacity': lipOpacity / 100.0,
      'lipStyle': lipStyle,
      'blushPreset': blushPreset,
      'blushOpacity': blushOpacity / 100.0,
      'blushStyle': blushStyle,
      'eyebrowPreset': eyebrowPreset,
      'eyebrowOpacity': eyebrowOpacity / 100.0,
      'eyebrowStyle': eyebrowStyle,
      'eyelinerPreset': eyelinerPreset,
      'eyelinerOpacity': eyelinerOpacity / 100.0,
      'eyelinerStyle': eyelinerStyle,
      'eyeshadowPreset': eyeshadowPreset,
      'eyeshadowOpacity': eyeshadowOpacity / 100.0,
      'eyeshadowStyle': eyeshadowStyle,
      'contourPreset': contourPreset,
      'contourOpacity': contourOpacity / 100.0,
      'contourStyle': contourStyle,
    };
  }

  factory MakeupSettings.fromJson(Map<String, dynamic> json) {
    return MakeupSettings(
      lipPreset: json['lipPreset'] as String? ?? 'none',
      lipOpacity: (json['lipOpacity'] as num?)?.toDouble() ?? 60,
      lipStyle: json['lipStyle'] as String? ?? 'full',
      blushPreset: json['blushPreset'] as String? ?? 'none',
      blushOpacity: (json['blushOpacity'] as num?)?.toDouble() ?? 50,
      blushStyle: json['blushStyle'] as String? ?? 'apple',
      eyebrowPreset: json['eyebrowPreset'] as String? ?? 'none',
      eyebrowOpacity: (json['eyebrowOpacity'] as num?)?.toDouble() ?? 50,
      eyebrowStyle: json['eyebrowStyle'] as String? ?? 'natural',
      eyelinerPreset: json['eyelinerPreset'] as String? ?? 'none',
      eyelinerOpacity: (json['eyelinerOpacity'] as num?)?.toDouble() ?? 60,
      eyelinerStyle: json['eyelinerStyle'] as String? ?? 'classic',
      eyeshadowPreset: json['eyeshadowPreset'] as String? ?? 'none',
      eyeshadowOpacity: (json['eyeshadowOpacity'] as num?)?.toDouble() ?? 50,
      eyeshadowStyle: json['eyeshadowStyle'] as String? ?? 'gradient',
      contourPreset: json['contourPreset'] as String? ?? 'none',
      contourOpacity: (json['contourOpacity'] as num?)?.toDouble() ?? 50,
      contourStyle: json['contourStyle'] as String? ?? 'vShape',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lipPreset': lipPreset,
      'lipOpacity': lipOpacity,
      'lipStyle': lipStyle,
      'blushPreset': blushPreset,
      'blushOpacity': blushOpacity,
      'blushStyle': blushStyle,
      'eyebrowPreset': eyebrowPreset,
      'eyebrowOpacity': eyebrowOpacity,
      'eyebrowStyle': eyebrowStyle,
      'eyelinerPreset': eyelinerPreset,
      'eyelinerOpacity': eyelinerOpacity,
      'eyelinerStyle': eyelinerStyle,
      'eyeshadowPreset': eyeshadowPreset,
      'eyeshadowOpacity': eyeshadowOpacity,
      'eyeshadowStyle': eyeshadowStyle,
      'contourPreset': contourPreset,
      'contourOpacity': contourOpacity,
      'contourStyle': contourStyle,
    };
  }
}
