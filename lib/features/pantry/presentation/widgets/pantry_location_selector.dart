import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/pantry_item.dart';

class PantryLocationSelector extends StatefulWidget {
  const PantryLocationSelector({
    required this.selectedLocation,
    required this.onLocationSelected,
    required this.locationCounts,
    super.key,
  });

  final PantryLocation? selectedLocation;
  final ValueChanged<PantryLocation?> onLocationSelected;
  final Map<PantryLocation?, int> locationCounts;

  @override
  State<PantryLocationSelector> createState() => _PantryLocationSelectorState();
}

class _PantryLocationSelectorState extends State<PantryLocationSelector> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _chipKeys = {
    for (var i = 0; i < _options.length; i++) i: GlobalKey(),
  };

  static const _options =
      <({String label, IconData icon, PantryLocation? value})>[
        (label: 'All', icon: Icons.grid_view_rounded, value: null),
        (
          label: 'Refrigerator',
          icon: Icons.kitchen_outlined,
          value: PantryLocation.refrigerator,
        ),
        (
          label: 'Freezer',
          icon: Icons.ac_unit_rounded,
          value: PantryLocation.freezer,
        ),
        (label: 'Pantry', icon: Icons.shelves, value: PantryLocation.pantry),
      ];

  @override
  void didUpdateWidget(covariant PantryLocationSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLocation != widget.selectedLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureSelectedVisible();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureSelectedVisible() {
    final index = _options.indexWhere(
      (option) => option.value == widget.selectedLocation,
    );
    if (index < 0) return;

    final context = _chipKeys[index]?.currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.35,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = _options[index];
          final isSelected = widget.selectedLocation == option.value;
          final count = widget.locationCounts[option.value] ?? 0;

          return KeyedSubtree(
            key: _chipKeys[index],
            child: _LocationChip(
              icon: option.icon,
              label: option.label,
              count: count,
              isSelected: isSelected,
              onTap: () => widget.onLocationSelected(option.value),
            ),
          );
        },
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? AppColors.white : AppColors.heading;
    final muted = isSelected
        ? AppColors.white.withValues(alpha: 0.9)
        : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen : AppColors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? AppColors.primaryGreen : AppColors.cardBorder,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: muted),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '·',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
