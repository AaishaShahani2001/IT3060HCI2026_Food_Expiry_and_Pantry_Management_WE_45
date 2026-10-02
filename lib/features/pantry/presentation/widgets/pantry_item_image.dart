import 'package:flutter/material.dart';

import '../../domain/models/pantry_item.dart';
import '../../domain/utils/pantry_image_url.dart';

/// Item thumbnail with display priority:
/// 1. User-uploaded photo (Cloudinary or a legacy Firebase Storage URL)
/// 2. Category symbol (always the fallback; also used when the network image fails)
///
/// There is no product-API image field on this model.
class PantryItemImage extends StatelessWidget {
  const PantryItemImage({
    required this.item,
    this.width,
    this.height,
    this.borderRadius,
    this.iconSize = 32,
    this.backgroundColor,
    this.iconColor,
    this.delivery = PantryImageDelivery.card,
    super.key,
  });

  final PantryItem item;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final double iconSize;
  final Color? backgroundColor;
  final Color? iconColor;
  final PantryImageDelivery delivery;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.zero;
    final fallback = _CategoryFallback(
      item: item,
      iconSize: iconSize,
      backgroundColor: backgroundColor ?? colorScheme.secondaryContainer,
      iconColor: iconColor ?? colorScheme.primary,
    );

    Widget child;
    if (item.hasUserPhoto) {
      child = Image.network(
        pantryDisplayImageUrl(item.photoUrl!, delivery: delivery),
        width: width,
        height: height,
        fit: BoxFit.cover,
        semanticLabel: '${item.name} photo',
        loadingBuilder: (context, image, progress) {
          if (progress == null) return image;
          return Stack(
            fit: StackFit.expand,
            children: [
              fallback,
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ],
          );
        },
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    } else {
      child = fallback;
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(width: width, height: height, child: child),
    );
  }
}

class _CategoryFallback extends StatelessWidget {
  const _CategoryFallback({
    required this.item,
    required this.iconSize,
    required this.backgroundColor,
    required this.iconColor,
  });

  final PantryItem item;
  final double iconSize;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${item.name}, ${item.category.label}',
      image: true,
      child: ColoredBox(
        color: backgroundColor,
        child: Center(
          child: Icon(item.category.icon, size: iconSize, color: iconColor),
        ),
      ),
    );
  }
}
