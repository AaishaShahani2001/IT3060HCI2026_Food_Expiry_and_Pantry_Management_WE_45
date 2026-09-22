import 'package:flutter/material.dart';

Duration wasteMotionDuration(BuildContext context, [int milliseconds = 240]) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

class WasteEntrance extends StatelessWidget {
  const WasteEntrance({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(
      begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0,
      end: 1,
    ),
    duration: wasteMotionDuration(context),
    curve: Curves.easeOut,
    child: child,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 6 * (1 - value)),
        child: child,
      ),
    ),
  );
}

class WastePress extends StatefulWidget {
  const WastePress({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<WastePress> createState() => _WastePressState();
}

class _WastePressState extends State<WastePress> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) {
      if (widget.enabled) setState(() => _pressed = true);
    },
    onPointerUp: (_) => setState(() => _pressed = false),
    onPointerCancel: (_) => setState(() => _pressed = false),
    child: AnimatedScale(
      scale: _pressed && widget.enabled ? 0.98 : 1,
      duration: wasteMotionDuration(context, 120),
      child: widget.child,
    ),
  );
}

class WasteSurface extends StatelessWidget {
  const WasteSurface({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
      boxShadow: [
        BoxShadow(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}
