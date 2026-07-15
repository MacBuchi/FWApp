/// image_utils.dart – Image-path resolution helpers.
/// Rules: "assets/" → Image.asset, `supabase://<bucket>/<object>` markers and
/// http(s) URLs → CachedNetworkImage (offline cache), all others → Image.file.
library;
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Prefix for centrally stored images. Markers stay stable when the server
/// address changes; the URL is built at display time from the configured base.
const kSupabaseImagePrefix = 'supabase://';

/// Base URL of the Supabase server (e.g. http://192.168.178.201:8000).
/// Set from main() when sync is active; null means markers cannot be
/// resolved and fall back to the placeholder.
String? supabaseStorageBaseUrl;

/// Auth headers (apikey + Bearer) for fetching from the private bucket.
/// A callback so the current access token is read per request.
Map<String, String> Function()? supabaseStorageHeaders;

bool isSupabaseImagePath(String? path) =>
    path != null && path.startsWith(kSupabaseImagePrefix);

bool isRemoteImagePath(String? path) =>
    isSupabaseImagePath(path) ||
    (path != null && (path.startsWith('http://') || path.startsWith('https://')));

/// True for paths pointing to files on this device (camera/gallery imports) —
/// the ones that are dead on other devices and need uploading.
bool isLocalImagePath(String? path) =>
    path != null &&
    path.isNotEmpty &&
    !path.startsWith('assets/') &&
    !isRemoteImagePath(path);

/// Resolves a supabase:// marker to the authenticated storage URL,
/// or null when no server is configured.
String? supabaseImageUrl(String marker) {
  final base = supabaseStorageBaseUrl;
  if (base == null || !isSupabaseImagePath(marker)) return null;
  final bucketAndObject = marker.substring(kSupabaseImagePrefix.length);
  return '$base/storage/v1/object/authenticated/$bucketAndObject';
}

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
  } else if (isRemoteImagePath(path)) {
    final url = isSupabaseImagePath(path) ? supabaseImageUrl(path) : path;
    if (url == null) return fallback;
    image = CachedNetworkImage(
      imageUrl: url,
      // The marker as cache key keeps cached entries valid across server moves
      // and lets the pull-time precache warm exactly this entry.
      cacheKey: path,
      httpHeaders: supabaseStorageHeaders?.call(),
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
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
