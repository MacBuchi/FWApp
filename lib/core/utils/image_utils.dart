/// image_utils.dart – Image-path resolution helpers.
/// Rule: paths starting with "assets/" use Image.asset(); all others use Image.file().
library;
import 'dart:io';
import 'package:flutter/material.dart';

/// Resolves an image path and returns the appropriate widget.
/// Defaults to [BoxFit.contain] so images are never cropped.
/// A [backgroundColor] (default light grey) is painted behind the image.
Widget resolveImage({
  required String? path,
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
  // Color(0xFFF5F5F5) == Colors.grey.shade100 — const-safe default
  Color? backgroundColor = const Color(0xFFF5F5F5),
  Widget? placeholder,
}) {
  final fallback = placeholder ??
      Container(
        width: width,
        height: height,
        color: backgroundColor ?? const Color(0xFFF5F5F5),
        child: const Icon(Icons.fire_truck, size: 48, color: Colors.grey),
      );

  if (path == null || path.isEmpty) return fallback;

  Widget image;
  if (path.startsWith('assets/')) {
    image = Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => fallback,
    );
  } else {
    image = Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  if (backgroundColor != null) {
    return Container(
      width: width,
      height: height,
      color: backgroundColor,
      alignment: Alignment.center,
      child: image,
    );
  }
  return image;
}

const kPlaceholderAsset = 'assets/images/placeholder_equipment.png';
