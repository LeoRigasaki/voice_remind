import 'package:flutter/material.dart';

class Space {
  final String id;
  final String name;
  final Color color;
  final IconData icon;
  final DateTime createdAt;

  const Space({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.createdAt,
  });

  // Convert Space to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color.toARGB32(),
      'icon': icon.codePoint,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  // Create Space from Map - FIXED to use constant IconData
  factory Space.fromMap(Map<String, dynamic> map) {
    // Get the icon codePoint and find matching constant IconData
    final int iconCodePoint = map['icon'] ?? Icons.folder_outlined.codePoint;
    final IconData resolvedIcon = _getIconFromCodePoint(iconCodePoint);

    return Space(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      color: Color(map['color'] ?? Colors.blue.value),
      icon: resolvedIcon,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  // Helper method to resolve IconData from codePoint using preset icons
  static IconData _getIconFromCodePoint(int codePoint) {
    // Try to find the icon in our preset icons first
    for (final icon in SpaceIcons.presetIcons) {
      if (icon.codePoint == codePoint) {
        return icon;
      }
    }

    // If not found in presets, check common Material icons
    final Map<int, IconData> commonIcons = {
      Icons.folder_outlined.codePoint: Icons.folder_outlined,
      Icons.work_outline.codePoint: Icons.work_outline,
      Icons.home_outlined.codePoint: Icons.home_outlined,
      Icons.shopping_cart_outlined.codePoint: Icons.shopping_cart_outlined,
      Icons.fitness_center_outlined.codePoint: Icons.fitness_center_outlined,
      Icons.school_outlined.codePoint: Icons.school_outlined,
      Icons.favorite_outline.codePoint: Icons.favorite_outline,
      Icons.star_outline.codePoint: Icons.star_outline,
      Icons.business.codePoint: Icons.business,
      Icons.apartment.codePoint: Icons.apartment,
      Icons.local_hospital.codePoint: Icons.local_hospital,
      Icons.restaurant.codePoint: Icons.restaurant,
      Icons.directions_car.codePoint: Icons.directions_car,
      Icons.flight.codePoint: Icons.flight,
      Icons.beach_access.codePoint: Icons.beach_access,
      Icons.pets.codePoint: Icons.pets,
    };

    // Return matching icon or default to folder_outlined
    return commonIcons[codePoint] ?? Icons.folder_outlined;
  }

  // copyWith method for immutable updates
  Space copyWith({
    String? id,
    String? name,
    Color? color,
    IconData? icon,
    DateTime? createdAt,
  }) {
    return Space(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Space(id: $id, name: $name, color: ${color.value}, icon: ${icon.codePoint})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Space && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Predefined space colors for quick selection
class SpaceColors {
  static const List<Color> presetColors = [
    Color(0xFFe36d30), // Orange
    Color(0xFF0088ff), // Blue
    Color(0xFFf14c42), // Red
    Color(0xFF3dcb40), // Green
    Color(0xFFdb9e1f), // Yellow
    Color(0xFF26c0a6), // Teal
    Color(0xFFe559c1), // Pink
    Color(0xFFee4d83), // Rose
    Color(0xFF875be0), // Purple
    Color(0xFF1c53bf), // Dark Blue
  ];
}

// Predefined space icons for quick selection
class SpaceIcons {
  static const List<IconData> presetIcons = [
    Icons.folder_outlined,
    Icons.work_outline,
    Icons.home_outlined,
    Icons.shopping_cart_outlined,
    Icons.fitness_center_outlined,
    Icons.school_outlined,
    Icons.favorite_outline,
    Icons.star_outline,
  ];

  static const List<String> iconLabels = [
    'General',
    'Work',
    'Home',
    'Shopping',
    'Health',
    'Education',
    'Personal',
    'Important',
  ];
}
