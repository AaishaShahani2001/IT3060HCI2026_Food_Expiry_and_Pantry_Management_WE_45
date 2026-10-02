import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../pantry/domain/models/pantry_item.dart';
import '../../../pantry/domain/utils/expiry_status.dart';
import '../../../pantry/presentation/widgets/pantry_item_image.dart';
import '../../domain/services/expiry_service.dart';

/// How strongly an expiry card should be emphasised.
///
/// Derived from the existing calendar-day rules: expired, Use First
/// ([ExpiryService.useFirstMaxDays]), and the expiring-soon window.
enum ExpiryCardUrgency { urgent, soon, critical, fresh, unknown }

ExpiryCardUrgency expiryCardUrgency(int? daysUntilExpiry) {
  if (daysUntilExpiry == null) return ExpiryCardUrgency.unknown;
  if (daysUntilExpiry < 0) return ExpiryCardUrgency.critical;
  if (daysUntilExpiry <= ExpiryService.useFirstMaxDays) {
    return ExpiryCardUrgency.urgent;
  }
  if (daysUntilExpiry <= kExpiryExpiringSoonDays) return ExpiryCardUrgency.soon;
  return ExpiryCardUrgency.fresh;
}

enum _ExpiryItemAction { update, stop }

/// Compact pantry item row used by the Expiry screen.
class ExpiryItemCard extends StatelessWidget {
  const ExpiryItemCard({
    super.key,
    required this.item,
    required this.message,
    required this.urgency,
    required this.onUpdate,
    required this.onStopTracking,
  });

  final PantryItem item;
  final String message;
  final ExpiryCardUrgency urgency;
  final VoidCallback onUpdate;
  final VoidCallback onStopTracking;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(16));
  static const double _wideLayoutWidth = 700;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = _accentColor(colorScheme);
    final cardColor = isDark
        ? colorScheme.surfaceContainerHighest
        : FreshPalette.card;
    final secondaryColor = isDark
        ? colorScheme.onSurfaceVariant
        : FreshPalette.secondaryText;
    final badge = _badgeLabel;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Material(
        color: cardColor,
        borderRadius: _radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: _radius,
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.7),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: ColoredBox(color: accent),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: PantryItemImage(
                        item: item,
                        width: 52,
                        height: 52,
                        iconSize: 26,
                        borderRadius: BorderRadius.circular(12),
                        backgroundColor: isDark
                            ? FreshPalette.darkAccentSurface
                            : FreshPalette.accentSurface,
                        iconColor: isDark
                            ? FreshPalette.highlight
                            : FreshPalette.primaryButton,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        label: _semanticLabel,
                        child: ExcludeSemantics(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.quantityLabel} • ${item.location.label}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: secondaryColor,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: accent,
                                            fontWeight: FontWeight.w700,
                                            height: 1.2,
                                          ),
                                      children: [
                                        WidgetSpan(
                                          alignment:
                                              PlaceholderAlignment.middle,
                                          child: Icon(
                                            _statusIcon,
                                            size: 16,
                                            color: accent,
                                          ),
                                        ),
                                        TextSpan(text: ' $message'),
                                      ],
                                    ),
                                  ),
                                  if (badge != null)
                                    _UrgencyBadge(label: badge, color: accent),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _ItemActionsButton(
                      itemName: item.name,
                      onSelected: (action) {
                        switch (action) {
                          case _ExpiryItemAction.update:
                            onUpdate();
                          case _ExpiryItemAction.stop:
                            onStopTracking();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentColor(ColorScheme colorScheme) {
    return switch (urgency) {
      ExpiryCardUrgency.urgent => AppColors.statusOrange,
      ExpiryCardUrgency.soon => AppColors.statusAmber,
      ExpiryCardUrgency.critical => AppColors.statusRed,
      ExpiryCardUrgency.fresh => AppColors.statusFresh,
      ExpiryCardUrgency.unknown => colorScheme.onSurfaceVariant,
    };
  }

  IconData get _statusIcon {
    return switch (urgency) {
      ExpiryCardUrgency.critical => Icons.event_busy_outlined,
      ExpiryCardUrgency.urgent => Icons.warning_amber_rounded,
      ExpiryCardUrgency.soon ||
      ExpiryCardUrgency.fresh ||
      ExpiryCardUrgency.unknown => Icons.schedule_outlined,
    };
  }

  String? get _badgeLabel {
    return switch (urgency) {
      ExpiryCardUrgency.urgent => 'URGENT',
      ExpiryCardUrgency.soon => 'SOON',
      ExpiryCardUrgency.critical => 'CRITICAL',
      ExpiryCardUrgency.fresh || ExpiryCardUrgency.unknown => null,
    };
  }

  String get _semanticLabel {
    final location = item.location.label.toLowerCase();
    final urgencyWord = switch (urgency) {
      ExpiryCardUrgency.urgent => ', urgent',
      ExpiryCardUrgency.soon => ', soon',
      ExpiryCardUrgency.critical => ', critical',
      ExpiryCardUrgency.fresh => ', fresh',
      ExpiryCardUrgency.unknown => '',
    };
    return '${item.name}, ${item.quantityLabel}, $location, ${message.toLowerCase()}$urgencyWord';
  }
}

class _UrgencyBadge extends StatelessWidget {
  const _UrgencyBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _ItemActionsButton extends StatelessWidget {
  const _ItemActionsButton({required this.itemName, required this.onSelected});

  final String itemName;
  final ValueChanged<_ExpiryItemAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Item actions',
      child: Semantics(
        button: true,
        label: 'Actions for $itemName',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _openActions(context),
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.more_vert),
          ),
        ),
      ),
    );
  }

  Future<void> _openActions(BuildContext context) async {
    final wide =
        MediaQuery.sizeOf(context).width >= ExpiryItemCard._wideLayoutWidth;
    final _ExpiryItemAction? action = wide
        ? await _showPopup(context)
        : await _showSheet(context);
    if (!context.mounted || action == null) return;
    onSelected(action);
  }

  Future<_ExpiryItemAction?> _showSheet(BuildContext context) {
    return showModalBottomSheet<_ExpiryItemAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.edit_calendar_outlined,
                  color: colorScheme.primary,
                ),
                title: Text(
                  'Update Expiry',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text('Change the tracked expiry date'),
                onTap: () =>
                    Navigator.pop(sheetContext, _ExpiryItemAction.update),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.notifications_off_outlined,
                  color: colorScheme.error,
                ),
                title: Text(
                  'Stop Tracking',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text('Remove expiry tracking only'),
                onTap: () =>
                    Navigator.pop(sheetContext, _ExpiryItemAction.stop),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<_ExpiryItemAction?> _showPopup(BuildContext context) {
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final colorScheme = Theme.of(context).colorScheme;

    return showMenu<_ExpiryItemAction>(
      context: context,
      position: RelativeRect.fromRect(
        origin & box.size,
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: _ExpiryItemAction.update,
          height: 68,
          child: _PopupAction(
            icon: Icons.edit_calendar_outlined,
            color: colorScheme.primary,
            title: 'Update Expiry',
            subtitle: 'Change the tracked expiry date',
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _ExpiryItemAction.stop,
          height: 68,
          child: _PopupAction(
            icon: Icons.notifications_off_outlined,
            color: colorScheme.error,
            title: 'Stop Tracking',
            subtitle: 'Remove expiry tracking only',
          ),
        ),
      ],
    );
  }
}

class _PopupAction extends StatelessWidget {
  const _PopupAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
