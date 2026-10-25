import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileAvatar extends StatefulWidget {
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

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  String? _decodedValue;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _cacheImageBytes();
  }

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageValue != widget.imageValue) {
      _cacheImageBytes();
    }
  }

  void _cacheImageBytes() {
    final value = widget.imageValue?.trim();
    _decodedValue = value;
    if (value == null || value.isEmpty || value.startsWith('http')) {
      _imageBytes = null;
      return;
    }
    try {
      final encoded = value.contains(',') ? value.split(',').last : value;
      _imageBytes = base64Decode(encoded);
    } catch (_) {
      _imageBytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _decodedValue;
    final initial = widget.name.trim().isNotEmpty
        ? widget.name.trim()[0].toUpperCase()
        : '?';

    Widget fallback() => CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.fallbackColor,
      child: Text(
        initial,
        style: GoogleFonts.plusJakartaSans(
          fontSize: widget.radius * 0.72,
          fontWeight: FontWeight.bold,
          color: widget.initialColor,
        ),
      ),
    );

    if (_imageBytes != null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.fallbackColor,
        child: ClipOval(
          child: Image.memory(
            _imageBytes!,
            width: widget.radius * 2,
            height: widget.radius * 2,
            cacheWidth: (widget.radius * 2).round(),
            fit: BoxFit.cover,
            errorBuilder: (context, error, _) => fallback(),
          ),
        ),
      );
    }

    if (value != null && value.isNotEmpty) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.fallbackColor,
        backgroundImage: NetworkImage(value),
        onBackgroundImageError: (exception, _) {},
      );
    }

    return fallback();
  }
}
