import 'package:flutter/material.dart';

import '../../data/local/pantry_food_catalog.dart';
import '../../domain/models/pantry_food_suggestion.dart';
import '../../domain/models/pantry_item.dart';

/// Item-name field with a local suggestion panel.
///
/// Suggestions are filtered from the in-memory catalogue plus [existingItems].
/// Nothing is written to Firestore from this field.
class PantryItemAutocompleteField extends StatefulWidget {
  const PantryItemAutocompleteField({
    required this.controller,
    required this.decoration,
    required this.validator,
    required this.onSuggestionSelected,
    required this.onNameEdited,
    this.existingItems = const [],
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final String? Function(String?) validator;
  final ValueChanged<PantryFoodSuggestion> onSuggestionSelected;
  final ValueChanged<String> onNameEdited;
  final List<PantryItem> existingItems;
  final bool enabled;

  @override
  State<PantryItemAutocompleteField> createState() =>
      _PantryItemAutocompleteFieldState();
}

class _PantryItemAutocompleteFieldState
    extends State<PantryItemAutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  late String _lastText;
  bool _userChangedName = false;
  bool _panelSuppressed = false;

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    widget.controller.addListener(_handleTextChanged);
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(PantryItemAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChanged);
      widget.controller.addListener(_handleTextChanged);
      _lastText = widget.controller.text;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  void _handleTextChanged() {
    final text = widget.controller.text;
    if (text == _lastText) return;
    _lastText = text;
    _userChangedName = true;
    _panelSuppressed = false;
    widget.onNameEdited(text);
    if (mounted) setState(() {});
  }

  void _handleSelected(PantryFoodSuggestion suggestion) {
    _panelSuppressed = true;
    widget.onSuggestionSelected(suggestion);
    if (mounted) setState(() {});
  }

  bool get _panelOpen {
    if (!_focusNode.hasFocus || !_userChangedName || _panelSuppressed) {
      return false;
    }
    return matchPantryFoodSuggestions(
      widget.controller.text,
      existingItems: widget.existingItems,
    ).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    // System back dismisses the open panel before leaving the form.
    return PopScope(
      canPop: !_panelOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _focusNode.unfocus();
      },
      child: RawAutocomplete<PantryFoodSuggestion>(
        textEditingController: widget.controller,
        focusNode: _focusNode,
        displayStringForOption: (option) => option.name,
        optionsViewOpenDirection: OptionsViewOpenDirection.mostSpace,
        optionsBuilder: (value) {
          // Edit and barcode prefill keep the loaded name. The panel stays
          // hidden until the user actually changes that text.
          if (!widget.enabled || !_userChangedName) {
            return const Iterable<PantryFoodSuggestion>.empty();
          }
          return matchPantryFoodSuggestions(
            value.text,
            existingItems: widget.existingItems,
          );
        },
        onSelected: _handleSelected,
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            enabled: widget.enabled,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: widget.decoration,
            validator: widget.validator,
            onFieldSubmitted: (_) => onFieldSubmitted(),
            // Mobile text fields keep focus after a touch outside. Unfocus so
            // the suggestion panel closes when the user taps another control.
            onTapOutside: (_) => focusNode.unfocus(),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          final suggestions = options.toList(growable: false);
          final colorScheme = Theme.of(context).colorScheme;
          final query = widget.controller.text;

          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: colorScheme.surface,
              elevation: 3,
              shadowColor: Colors.black,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    primary: false,
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = suggestions[index];
                      final highlighted =
                          AutocompleteHighlightedOption.of(context) == index;
                      return _SuggestionTile(
                        suggestion: suggestion,
                        query: query,
                        highlighted: highlighted,
                        onSelected: () => onSelected(suggestion),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.suggestion,
    required this.query,
    required this.highlighted,
    required this.onSelected,
  });

  final PantryFoodSuggestion suggestion;
  final String query;
  final bool highlighted;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final nameStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    return Semantics(
      button: true,
      label: '${suggestion.name}, ${suggestion.category.label}',
      child: InkWell(
        key: ValueKey('pantry-suggestion-${suggestion.name}'),
        onTap: onSelected,
        child: ExcludeSemantics(
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            color: highlighted ? colorScheme.secondaryContainer : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  suggestion.category.icon,
                  size: 22,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HighlightedName(
                        name: suggestion.name,
                        query: query,
                        style: nameStyle,
                      ),
                      Text(
                        suggestion.category.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightedName extends StatelessWidget {
  const _HighlightedName({
    required this.name,
    required this.query,
    required this.style,
  });

  final String name;
  final String query;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = normalizeFoodName(query);
    final matchIndex = normalizedQuery.isEmpty
        ? -1
        : name.toLowerCase().indexOf(normalizedQuery);
    if (matchIndex < 0) {
      return Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final matchEnd = matchIndex + normalizedQuery.length;
    final base = style ?? DefaultTextStyle.of(context).style;
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: name.substring(0, matchIndex)),
          TextSpan(
            text: name.substring(matchIndex, matchEnd),
            style: base.copyWith(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: name.substring(matchEnd)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
