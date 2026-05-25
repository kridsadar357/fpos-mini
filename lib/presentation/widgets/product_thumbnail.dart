import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class ProductThumbnail extends StatelessWidget {
  final String? imagePath;
  final double size;
  final IconData fallbackIcon;
  final Color? iconColor;
  final BoxFit fit;

  const ProductThumbnail({
    super.key,
    this.imagePath,
    this.size = 44,
    this.fallbackIcon = Icons.shopping_bag_rounded,
    this.iconColor,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.corporateBlue;
    final hasImage = !kIsWeb &&
        imagePath != null &&
        imagePath!.isNotEmpty &&
        File(imagePath!).existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        color: AppColors.softWhite,
        child: hasImage
            ? Image.file(
                File(imagePath!),
                width: size,
                height: size,
                fit: fit,
                errorBuilder: (_, __, ___) => _fallback(color),
              )
            : _fallback(color),
      ),
    );
  }

  Widget _fallback(Color color) {
    return Center(
      child: Icon(
        fallbackIcon,
        color: color,
        size: size * 0.55,
      ),
    );
  }
}
