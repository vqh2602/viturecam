import 'package:flutter/material.dart';

class FilterPreset {
  final String id;
  final String name;
  final String category;
  final List<Color> gradient;
  final double defaultIntensity;

  const FilterPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.gradient,
    this.defaultIntensity = 80,
  });
}

class FilterCatalog {
  static const List<FilterPreset> presets = [
    FilterPreset(
      id: 'original',
      name: 'Original',
      category: 'Natural',
      gradient: [Color(0xFF555555), Color(0xFF777777)],
      defaultIntensity: 0,
    ),
    FilterPreset(
      id: 'clear',
      name: 'Clear',
      category: 'Natural',
      gradient: [Color(0xFF89F7FE), Color(0xFF66A6FF)],
      defaultIntensity: 80,
    ),
    FilterPreset(
      id: 'milk',
      name: 'Milk',
      category: 'Korean',
      gradient: [Color(0xFFFEE140), Color(0xFFFA709A)],
      defaultIntensity: 75,
    ),
    FilterPreset(
      id: 'film',
      name: 'Film',
      category: 'Film',
      gradient: [Color(0xFF30E8BF), Color(0xFFFF8235)],
      defaultIntensity: 85,
    ),
    FilterPreset(
      id: 'warm',
      name: 'Warm',
      category: 'Warm',
      gradient: [Color(0xFFFF9966), Color(0xFFFF5E62)],
      defaultIntensity: 80,
    ),
    FilterPreset(
      id: 'cool',
      name: 'Cool',
      category: 'Cool',
      gradient: [Color(0xFF4CA1AF), Color(0xFF2C3E50)],
      defaultIntensity: 75,
    ),
    FilterPreset(
      id: 'retro',
      name: 'Retro',
      category: 'Vintage',
      gradient: [Color(0xFFC06C84), Color(0xFF6C5B7B)],
      defaultIntensity: 80,
    ),
    FilterPreset(
      id: 'peach',
      name: 'Peach',
      category: 'Portrait',
      gradient: [Color(0xFFFF758C), Color(0xFFFF7EB3)],
      defaultIntensity: 85,
    ),
    FilterPreset(
      id: 'bw',
      name: 'B&W',
      category: 'B&W',
      gradient: [Color(0xFF232526), Color(0xFF414345)],
      defaultIntensity: 90,
    ),
  ];
}
