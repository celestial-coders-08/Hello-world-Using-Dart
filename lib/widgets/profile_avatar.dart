import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileAvatar extends StatelessWidget {
  final String name;
  final String? imageValue;
  final double radius;
  final Color fallbackColor;
  final Color initialColor;

  const ProfileAvatar({
    super.key,
    required this.name,
    this.imageValue,
    this.radius = 28,
    this.fallbackColor = const Color(0xFFF3EBE4),
    this.initialColor = const Color(0xFFCA6347),
  });

  Uint8List? _decodeImage(String value) {
    try {
      final encoded = value.contains(',') ? value.split(',').last : value;
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = imageValue?.trim();
    final imageBytes =
        value == null || value.isEmpty || value.startsWith('http')
        ? null
        : _decodeImage(value);
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    Widget fallback() => CircleAvatar(
      radius: radius,
      backgroundColor: fallbackColor,
      child: Text(
        initial,
        style: GoogleFonts.plusJakartaSans(
          fontSize: radius * 0.72,
          fontWeight: FontWeight.bold,
          color: initialColor,
        ),
      ),
    );

    if (imageBytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: fallbackColor,
        child: ClipOval(
          child: Image.memory(
            imageBytes,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback(),
          ),
        ),
      );
    }

    if (value != null && value.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: fallbackColor,
        backgroundImage: NetworkImage(value),
        onBackgroundImageError: (_, __) {},
      );
    }

    return fallback();
  }
}
