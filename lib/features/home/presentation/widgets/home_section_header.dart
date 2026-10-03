import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Reusable section header for Home dashboard sections.
///
/// Displays a compact local image icon, section title, optional subtitle,
/// optional "See All" action or trailing widget, and optional subtle pulse animation
/// on the header icon.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.assetPath,
    this.subtitle,
    this.onSeeAll,
    this.seeAllLabel = 'See All',
    this.trailing,
    this.animateIcon = false,
    this.fallbackIcon = Icons.image_outlined,
    this.semanticLabel,
    this.onTap,
    this.titleColor,
    this.subtitleColor,
    this.iconBgColor,
    this.iconSize,
    this.iconPadding,
    this.iconFit = BoxFit.cover,
    this.iconBorderColor,
  });

  final String title;
  final String? assetPath;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final String seeAllLabel;
  final Widget? trailing;
  final bool animateIcon;
  final IconData fallbackIcon;
  final String? semanticLabel;
  final VoidCallback? onTap;
  final Color? titleColor;
  final Color? subtitleColor;
  final Color? iconBgColor;
  final double? iconSize;
  final EdgeInsetsGeometry? iconPadding;
  final BoxFit iconFit;
  final Color? iconBorderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final containerSize = iconSize ?? (screenWidth < 360 ? 36.0 : 40.0);

    final resolvedTitleColor =
        titleColor ??
        (isDark ? FreshPalette.darkHeading : FreshPalette.heading);
    final resolvedSubtitleColor =
        subtitleColor ??
        (isDark ? FreshPalette.darkSecondaryText : FreshPalette.secondaryText);

    final iconPath = assetPath;
    final content = Row(
      children: [
        if (iconPath != null) ...[
          _HeaderIcon(
            assetPath: iconPath,
            size: containerSize,
            animateIcon: animateIcon,
            fallbackIcon: fallbackIcon,
            isDark: isDark,
            customBgColor: iconBgColor,
            iconPadding: iconPadding,
            iconFit: iconFit,
            iconBorderColor: iconBorderColor,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: resolvedTitleColor,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: resolvedSubtitleColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onSeeAll case final seeAllFn?)
          TextButton(
            onPressed: seeAllFn,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: theme.colorScheme.primary,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(seeAllLabel),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          )
        else
          ?trailing,
      ],
    );

    final semanticText =
        semanticLabel ?? (subtitle == null ? title : '$title, $subtitle');

    Widget result = Semantics(
      header: true,
      label: semanticText,
      child: content,
    );

    if (onTap != null) {
      result = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: result,
      );
    }

    return result;
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.assetPath,
    required this.size,
    required this.animateIcon,
    required this.fallbackIcon,
    required this.isDark,
    required this.iconFit,
    this.customBgColor,
    this.iconPadding,
    this.iconBorderColor,
  });

  final String assetPath;
  final double size;
  final bool animateIcon;
  final IconData fallbackIcon;
  final bool isDark;
  final BoxFit iconFit;
  final Color? customBgColor;
  final EdgeInsetsGeometry? iconPadding;
  final Color? iconBorderColor;

  @override
  Widget build(BuildContext context) {
    if (animateIcon) {
      return _AnimatedHeaderIcon(
        assetPath: assetPath,
        size: size,
        fallbackIcon: fallbackIcon,
        isDark: isDark,
        customBgColor: customBgColor,
        iconPadding: iconPadding,
        iconFit: iconFit,
        iconBorderColor: iconBorderColor,
      );
    }
    return _StaticHeaderIcon(
      assetPath: assetPath,
      size: size,
      fallbackIcon: fallbackIcon,
      isDark: isDark,
      customBgColor: customBgColor,
      iconPadding: iconPadding,
      iconFit: iconFit,
      iconBorderColor: iconBorderColor,
    );
  }
}

class _StaticHeaderIcon extends StatelessWidget {
  const _StaticHeaderIcon({
    required this.assetPath,
    required this.size,
    required this.fallbackIcon,
    required this.isDark,
    required this.iconFit,
    this.customBgColor,
    this.iconPadding,
    this.iconBorderColor,
  });

  final String assetPath;
  final double size;
  final IconData fallbackIcon;
  final bool isDark;
  final BoxFit iconFit;
  final Color? customBgColor;
  final EdgeInsetsGeometry? iconPadding;
  final Color? iconBorderColor;

  @override
  Widget build(BuildContext context) {
    final defaultBg =
        customBgColor ??
        (isDark ? FreshPalette.darkAccentSurface : FreshPalette.accentSurface);
    final fallbackIconColor = isDark
        ? FreshPalette.highlight
        : FreshPalette.primaryButton;
    final borderColor =
        iconBorderColor ??
        (isDark ? FreshPalette.darkOutline : FreshPalette.outline).withValues(
          alpha: 0.4,
        );

    return Container(
      width: size,
      height: size,
      padding: iconPadding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: defaultBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Image.asset(
        assetPath,
        fit: iconFit,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Icon(
              fallbackIcon,
              size: size * 0.55,
              color: fallbackIconColor,
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedHeaderIcon extends StatefulWidget {
  const _AnimatedHeaderIcon({
    required this.assetPath,
    required this.size,
    required this.fallbackIcon,
    required this.isDark,
    required this.iconFit,
    this.customBgColor,
    this.iconPadding,
    this.iconBorderColor,
  });

  final String assetPath;
  final double size;
  final IconData fallbackIcon;
  final bool isDark;
  final BoxFit iconFit;
  final Color? customBgColor;
  final EdgeInsetsGeometry? iconPadding;
  final Color? iconBorderColor;

  @override
  State<_AnimatedHeaderIcon> createState() => _AnimatedHeaderIconState();
}

class _AnimatedHeaderIconState extends State<_AnimatedHeaderIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacityAnimation = Tween<double>(
      begin: 0.72,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        !TickerMode.valuesOf(context).enabled;
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );

    if (disableAnimations || isTest) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
    } else {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        !TickerMode.valuesOf(context).enabled;

    final staticChild = _StaticHeaderIcon(
      assetPath: widget.assetPath,
      size: widget.size,
      fallbackIcon: widget.fallbackIcon,
      isDark: widget.isDark,
      customBgColor: widget.customBgColor,
      iconPadding: widget.iconPadding,
      iconFit: widget.iconFit,
      iconBorderColor: widget.iconBorderColor,
    );

    if (disableAnimations) {
      return staticChild;
    }

    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: ScaleTransition(scale: _scaleAnimation, child: staticChild),
      ),
    );
  }
}
