import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/low_stock_shopping_sync_provider.dart';
import '../providers/shopping_list_provider.dart';

/// Mounted once below MaterialApp's messenger, above its routed screens.
class LowStockShoppingSyncHost extends ConsumerStatefulWidget {
  const LowStockShoppingSyncHost({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<LowStockShoppingSyncHost> createState() => _SyncHostState();
}

class _SyncHostState extends ConsumerState<LowStockShoppingSyncHost> {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _notice;

  @override
  Widget build(BuildContext context) {
    ref.listen(shoppingAuthUidProvider, (before, after) {
      if (before?.asData?.value == after.asData?.value) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notice?.close();
      });
    });
    ref.listen(lowStockShoppingSyncProvider, (before, after) {
      final event = after.asData?.value;
      if (event == null || identical(before?.asData?.value, event)) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            ref.read(shoppingAuthUidProvider).asData?.value != event.uid ||
            !identical(
              ref.read(lowStockShoppingSyncProvider).asData?.value,
              event,
            )) {
          return;
        }
        _notice?.close();
        _notice = ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(event.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
        final notice = _notice;
        notice?.closed.then((_) {
          if (identical(_notice, notice)) _notice = null;
        });
      });
    });
    return widget.child;
  }
}
