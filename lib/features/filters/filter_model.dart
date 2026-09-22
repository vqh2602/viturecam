import 'package:flutter/material.dart';

class FilterPreset {
  final String id;
  final String name;
  final String category;
  final List<Color> gradient;
  final double defaultIntensity;
  final bool isLut;

  const FilterPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.gradient,
    this.defaultIntensity = 80,
    this.isLut = true,
  });

  String get lutCubePath => id == 'original' ? '' : 'assets/luts/$id.cube';
  String get lutPngPath => id == 'original' ? '' : 'assets/luts/$id.png';
}

class FilterCatalog {
  static const List<FilterPreset> presets = [
    // --- Natural (Tự nhiên & Trong trẻo) ---
    FilterPreset(
      id: 'original',
      name: 'Original',
      category: 'Natural',
      gradient: [Color(0xFF555555), Color(0xFF777777)],
      defaultIntensity: 0,
      isLut: false,
    ),
    FilterPreset(
      id: 'clear',
      name: 'Clear',
      category: 'Natural',
      gradient: [Color(0xFF89F7FE), Color(0xFF66A6FF)],
      defaultIntensity: 80,
    ),
    FilterPreset(
      id: 'pure',
      name: 'Pure',
      category: 'Natural',
      gradient: [Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
      defaultIntensity: 80,
    ),
    FilterPreset(
      id: 'clean',
      name: 'Clean',
      category: 'Natural',
      gradient: [Color(0xFFACCBEE), Color(0xFFE7F0FD)],
      defaultIntensity: 75,
    ),
    FilterPreset(
      id: 'dewy',
      name: 'Dewy',
      category: 'Natural',
      gradient: [Color(0xFFA8EDEA), Color(0xFFFED6E3)],
      defaultIntensity: 85,
    ),

    // --- Korean (Hàn Quốc & Idol) ---
    FilterPreset(
      id: 'milk',
      name: 'Milk',
      category: 'Korean',
      gradient: [Color(0xFFFFF1EB), Color(0xFFACE0F9)],
      defaultIntensity: 75,
    ),
    FilterPreset(
      id: 'peach',
      name: 'Peach',
      category: 'Korean',
      gradient: [Color(0xFFFF9A9E), Color(0xFFFAD0C4)],
      defaultIntensity: 85,
    ),
    FilterPreset(
      id: 'sakura',
      name: 'Sakura',
      category: 'Korean',
      gradient: [Color(0xFFFFB199), Color(0xFFFF0844)],
      defaultIntensity: 80,
    ),
    FilterPreset(
      id: 'cream',
      name: 'Cream',
      category: 'Korean',
      gradient: [Color(0xFFFDFBFB), Color(0xFFEBEDEE)],
      defaultIntensity: 75,
    ),
    FilterPreset(
      id: 'idol',
      name: 'Idol',
      category: 'Korean',
      gradient: [Color(0xFFF857A6), Color(0xFFFF5858)],
      defaultIntensity: 80,
    ),

    // --- Douyin (Sáng Trong & Xinh Xắn) ---
    FilterPreset(
      id: 'douyin_fairy',
      name: 'Tiên Nữ',
      category: 'Douyin',
      gradient: [Color(0xFFFFC3A0), Color(0xFFFFAFBD)],
      defaultIntensity: 85,
    ),
    FilterPreset(
      id: 'douyin_sweet',
      name: 'Ngọt Ngào',
      category: 'Douyin',
      gradient: [Color(0xFFFF9A9E), Color(0xFFFECFEF)],
      defaultIntensity: 85,
    ),
    FilterPreset(
      id: 'douyin_moon',
      name: 'Bạch Nguyệt',
      category: 'Douyin',
      gradient: [Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
      defaultIntensity: 85,
    ),
    FilterPreset(
      id: 'douyin_dreamy',
      name: 'Mộng Ảo',
      category: 'Douyin',
      gradient: [Color(0xFFFBC2EB), Color(0xFFA6C1EE)],
      defaultIntensity: 80,
    ),
    FilterPreset(
      id: 'douyin_doll',
      name: 'Búp Bê',
      category: 'Douyin',
      gradient: [Color(0xFFFF758C), Color(0xFFFF7EB3)],
      defaultIntensity: 85,
    ),
    FilterPreset(
      id: 'douyin_radiant',
      name: 'Phát Sáng',
      category: 'Douyin',
      gradient: [Color(0xFFFA709A), Color(0xFFFEE140)],
      defaultIntensity: 85,
    ),
    FilterPreset(
      id: 'douyin_vintage',
      name: 'Cổ Điển Hồng',
      category: 'Douyin',
      gradient: [Color(0xFFEE9CA7), Color(0xFFFFDDE1)],
      defaultIntensity: 80,
    ),

    // --- Film (Điện ảnh & Vintage) ---
    FilterPreset(
      id: 'film',
      name: 'Film',
      category: 'Film',
      gradient: [Color(0xFF30E8BF), Color(0xFFFF8235)],
      defaultIntensity: 85,
    ),
    FilterPreset(
      id: 'kodak',
      name: 'Kodak',
      category: 'Film',
      gradient: [Color(0xFFFFB347), Color(0xFFFFCC33)],
      defaultIntensity: 80,
    ),
    FilterPreset(
      id: 'fuji',
      name: 'Fuji',
      category: 'Film',
      gradient: [Color(0xFF00B4DB), Color(0xFF0083B0)],
      defaultIntensity: 80,
    ),
    FilterPreset(
      id: 'retro',
      name: 'Retro',
      category: 'Film',
      gradient: [Color(0xFFC06C84), Color(0xFF6C5B7B)],
      defaultIntensity: 80,
    ),
    FilterPreset(
      id: 'vintage',
      name: 'Vintage',
      category: 'Film',
      gradient: [Color(0xFFD4A373), Color(0xFFCCD5AE)],
      defaultIntensity: 80,
    ),
    FilterPreset(
      id: 'cinema',
      name: 'Cinema',
      category: 'Film',
      gradient: [Color(0xFF2C3E50), Color(0xFFFD746C)],
      defaultIntensity: 85,
    ),

    // --- Warm (Ấm áp & Mùa thu) ---
    FilterPreset(
      id: 'warm',
      name: 'Warm',
      category: 'Warm',
      gradient: [Color(0xFFFF9966), Color(0xFFFF5E62)],
      defaultIntensity: 80,
    ),
    FilterPreset(
      id: 'sunset',
      name: 'Sunset',
      category: 'Warm',
      gradient: [Color(0xFFFA709A), Color(0xFFFEE140)],
      defaultIntensity: 85,
    ),
    FilterPreset(
      id: 'latte',
      name: 'Latte',
      category: 'Warm',
      gradient: [Color(0xFFBC8567), Color(0xFFDDA77B)],
      defaultIntensity: 80,
    ),
    FilterPreset(
      id: 'autumn',
      name: 'Autumn',
      category: 'Warm',
      gradient: [Color(0xFFE65C00), Color(0xFFF9D423)],
      defaultIntensity: 80,
    ),

    // --- Cool (Lạnh lùng & Hiện đại) ---
    FilterPreset(
      id: 'cool',
      name: 'Cool',
      category: 'Cool',
      gradient: [Color(0xFF4CA1AF), Color(0xFF2C3E50)],
      defaultIntensity: 75,
    ),
    FilterPreset(
      id: 'nordic',
      name: 'Nordic',
      category: 'Cool',
      gradient: [Color(0xFF6190E8), Color(0xFFA7BFE8)],
      defaultIntensity: 80,
    ),
    FilterPreset(
      id: 'cyber',
      name: 'Cyber',
      category: 'Cool',
      gradient: [Color(0xFF8A2387), Color(0xFFE94057)],
      defaultIntensity: 85,
    ),

    // --- B&W (Đơn sắc Nghệ thuật) ---
    FilterPreset(
      id: 'bw',
      name: 'B&W',
      category: 'B&W',
      gradient: [Color(0xFF232526), Color(0xFF414345)],
      defaultIntensity: 90,
    ),
    FilterPreset(
      id: 'noir',
      name: 'Noir',
      category: 'B&W',
      gradient: [Color(0xFF000000), Color(0xFF434343)],
      defaultIntensity: 90,
    ),
    FilterPreset(
      id: 'silver',
      name: 'Silver',
      category: 'B&W',
      gradient: [Color(0xFFB7B7B7), Color(0xFFECE9E6)],
      defaultIntensity: 85,
    ),
  ];
}
