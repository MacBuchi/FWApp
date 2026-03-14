/// image_utils.dart – Image-path resolution helpers.
/// Rule: paths starting with "assets/" use Image.asset(); all others use Image.file().
import 'dart:io';
import 'package:flutter/material.dart';

Widget resolveImage({
  required String? path,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? placeholder,
}) {
  final fallback = placeholder ??
      Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: const Icon(Icons.fire_truck, size: 48, color: Colors.grey),
      );

  if (path == null || path.isEmpty) return fallback;

  if (path.startsWith('assets/')) {
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  final file = File(path);
  return Image.file(
    file,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, __, ___) => fallback,
  );
}

const kPlaceholderAsset = 'assets/images/placeholder_equipment.png';
