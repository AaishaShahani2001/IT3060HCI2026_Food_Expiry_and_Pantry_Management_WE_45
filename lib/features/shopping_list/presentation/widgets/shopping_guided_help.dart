import 'package:flutter/material.dart';

class ShoppingHelpStep {
  const ShoppingHelpStep({
    required this.targetKey,
    required this.title,
    required this.description,
  });

  final GlobalKey targetKey;
  final String title;
  final String description;
}

Future<void> showShoppingGuidedHelp(
  BuildContext context,
  List<ShoppingHelpStep> steps,
) {
  final available = [
    for (final step in steps)
      if (step.targetKey.currentContext != null) step,
  ];
  if (available.isEmpty) return Future.value();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _ShoppingGuidedHelpOverlay(steps: available),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _ShoppingGuidedHelpOverlay extends StatefulWidget {
  const _ShoppingGuidedHelpOverlay({required this.steps});

  final List<ShoppingHelpStep> steps;

  @override
  State<_ShoppingGuidedHelpOverlay> createState() =>
      _ShoppingGuidedHelpOverlayState();
}

class _ShoppingGuidedHelpOverlayState
    extends State<_ShoppingGuidedHelpOverlay> {
  int _index = 0;
  Rect? _target;
  bool _moving = false;

  ShoppingHelpStep get _step => widget.steps[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCurrentTarget());
  }

  Future<void> _showCurrentTarget() async {
    if (_moving) return;
    _moving = true;
    final targetContext = _step.targetKey.currentContext;
    if (targetContext == null) {
      _moving = false;
      return;
    }
    await Scrollable.ensureVisible(
      targetContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final renderObject =
        _step.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderObject != null && renderObject.hasSize) {
      final origin = renderObject.localToGlobal(Offset.zero);
      setState(() {
        _target = (origin & renderObject.size).inflate(6);
      });
    }
    _moving = false;
  }

  void _moveTo(int index) {
    if (_moving || index < 0 || index >= widget.steps.length) return;
    setState(() {
      _index = index;
      _target = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCurrentTarget());
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final target = _target;
    final putCardAtTop =
        target != null && target.center.dy > media.size.height / 2;
    final colors = Theme.of(context).colorScheme;
    final isLast = _index == widget.steps.length - 1;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SpotlightPainter(
                target: target,
                overlayColor: Colors.black.withValues(alpha: 0.72),
                borderColor: colors.primaryContainer,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: putCardAtTop ? media.padding.top + 16 : null,
            bottom: putCardAtTop ? null : media.padding.bottom + 16,
            child: SafeArea(
              top: false,
              bottom: false,
              child: Card(
                key: const ValueKey('shopping-help-card'),
                elevation: 10,
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: colors.outline),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_index + 1} of ${widget.steps.length}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _step.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(_step.description),
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Skip'),
                          ),
                          if (_index > 0)
                            OutlinedButton(
                              onPressed: () => _moveTo(_index - 1),
                              child: const Text('Back'),
                            ),
                          FilledButton(
                            onPressed: isLast
                                ? () => Navigator.pop(context)
                                : () => _moveTo(_index + 1),
                            child: Text(isLast ? 'Done' : 'Next'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.target,
    required this.overlayColor,
    required this.borderColor,
  });

  final Rect? target;
  final Color overlayColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fullScreen = Path()..addRect(Offset.zero & size);
    final target = this.target;
    if (target == null) {
      canvas.drawPath(fullScreen, Paint()..color = overlayColor);
      return;
    }
    final safeTarget = target.intersect(Offset.zero & size);
    final spotlight = Path()
      ..addRRect(
        RRect.fromRectAndRadius(safeTarget, const Radius.circular(14)),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, fullScreen, spotlight),
      Paint()..color = overlayColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(safeTarget, const Radius.circular(14)),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.target != target ||
      oldDelegate.overlayColor != overlayColor ||
      oldDelegate.borderColor != borderColor;
}
