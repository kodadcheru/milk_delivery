import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Utilities for optimizing image URLs from popular CDNs (Unsplash, Cloudinary, etc.)
class ImageUtils {
  /// Rewrites URLs to request optimized, downscaled WebP/JPEG thumbnails
  /// reducing image transfer from ~3-5MB down to ~25-40KB.
  static String optimizeUrl(String url, {int width = 350, int quality = 75}) {
    if (url.isEmpty) return url;

    // Unsplash optimization
    if (url.contains('images.unsplash.com')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final queryParams = Map<String, String>.from(uri.queryParameters);
        queryParams['w'] = width.toString();
        queryParams['q'] = quality.toString();
        queryParams['auto'] = 'format';
        queryParams['fit'] = 'crop';
        return uri.replace(queryParameters: queryParams).toString();
      }
    }

    // Cloudinary optimization
    if (url.contains('res.cloudinary.com') && url.contains('/upload/')) {
      final parts = url.split('/upload/');
      if (parts.length == 2) {
        return '${parts[0]}/upload/f_auto,q_auto,w_$width,c_limit/${parts[1]}';
      }
    }

    return url;
  }
}

/// High-performance drop-in image widget with disk caching, memory bounds,
/// smooth crossfade, and graceful fallback handling.
class AppCachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String fallbackIcon;
  final Color? fallbackBgColor;
  final int memCacheWidth;
  final int memCacheHeight;
  final Widget? customPlaceholder;
  final Widget? customErrorWidget;

  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = '🥛',
    this.fallbackBgColor,
    this.memCacheWidth = 400,
    this.memCacheHeight = 400,
    this.customPlaceholder,
    this.customErrorWidget,
  });

  /// Cached image provider for use in `DecorationImage` or `CircleAvatar`
  static ImageProvider provider(String url, {int maxWidth = 400, int maxHeight = 400}) {
    final cleanUrl = url.trim();
    final optimized = ImageUtils.optimizeUrl(cleanUrl, width: maxWidth);
    if (optimized.isEmpty || (!optimized.startsWith('http://') && !optimized.startsWith('https://'))) {
      return const AssetImage('assets/images/placeholder.png');
    }
    return CachedNetworkImageProvider(
      optimized,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    if (cleanUrl.isEmpty || (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://'))) {
      return _buildFallback();
    }

    final optimizedUrl = ImageUtils.optimizeUrl(cleanUrl, width: memCacheWidth);

    Widget imageWidget = CachedNetworkImage(
      imageUrl: optimizedUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: const Duration(milliseconds: 180),
      fadeOutDuration: const Duration(milliseconds: 100),
      placeholder: (context, url) => customPlaceholder ?? _buildPlaceholder(),
      errorWidget: (context, url, error) => customErrorWidget ?? _buildFallback(),
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Opacity(
          opacity: 0.35,
          child: Text(
            fallbackIcon,
            style: TextStyle(fontSize: (height != null && height! < 50) ? 18 : 26),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fallbackBgColor ?? const Color(0xFFF1F5F9),
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Text(
          fallbackIcon,
          style: TextStyle(fontSize: (height != null && height! < 50) ? 20 : 30),
        ),
      ),
    );
  }
}
