import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF121212);
  static const Color card = Color(0xFF1E1E1E);
  static const Color primary = Color(
    0xFF1565C0,
  ); // Azul más legible // 🔵 nuevo azul
  static const Color accent = Color.fromARGB(
    255,
    0,
    77,
    221,
  ); // 🔵 íconos y detalles
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color error = Color(0xFFFF5252);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107); // 🟡 amarillo tipo alerta
}

IconData getIconFromName(String? name) {
  switch (name) {
    case 'restaurant':
      return Icons.restaurant;
    case 'directions_car':
      return Icons.directions_car;
    case 'bolt':
      return Icons.bolt;
    case 'sports_esports':
      return Icons.sports_esports;
    case 'local_hospital':
      return Icons.local_hospital;
    case 'school':
      return Icons.school;
    case 'category':
      return Icons.category;
    case 'celebration':
      return Icons.celebration;
    default:
      return Icons.label;
  }
}

Color hexToColor(String? hex) {
  if (hex == null || hex.isEmpty) return Colors.grey;
  hex = hex.replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}
