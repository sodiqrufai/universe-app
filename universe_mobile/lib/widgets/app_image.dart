import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

/// Standard cached network image: same loading spinner and broken-image
/// look everywhere, and actual on-disk caching instead of re-downloading
/// the same avatar/listing photo every time a screen rebuilds.
///
/// Drop-in replacement for `Image.network(url, width: .., height: ..,
/// fit: .., errorBuilder: ..)`: pass the same width/height/fit and skip
/// errorBuilder, this handles it.
///
/// If the image can't be loaded (offline, slow server, a browser blocking
/// the request) the broken-image tile is tappable: tapping it tries again.
/// An empty or missing URL shows the same placeholder tile instead of
/// throwing.
class AppNetworkImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const AppNetworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  // Bumped when the user taps a broken image, which rebuilds the image
  // widget from scratch and so asks for the file again.
  int _attempt = 0;

  Widget _tile(Widget child) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: AppColors.lightPurple,
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget image;
    if (widget.url.trim().isEmpty) {
      image = _tile(Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted));
    } else {
      image = CachedNetworkImage(
        key: ValueKey('${widget.url}#$_attempt'),
        imageUrl: widget.url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (context, url) => _tile(
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ),
        errorWidget: (context, url, error) => Semantics(
          button: true,
          label: "Image couldn't load. Tap to try again",
          child: GestureDetector(
            onTap: () => setState(() => _attempt++),
            child: _tile(
              Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }
    if (widget.borderRadius == null) return image;
    return ClipRRect(borderRadius: widget.borderRadius!, child: image);
  }
}
