import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// A modern, searchable dropdown component.
/// 
/// Design requirements:
/// - Modern design
/// - Searchable (type to filter)
/// - Big tap targets (thumb-friendly)
/// - Fast (cached data)
/// - "All" default with optional drill-down
class PremiumDropdown<T> extends StatefulWidget {
  const PremiumDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.itemLabel,
    this.label,
    this.hint,
    this.searchable = true,
    this.allOptionLabel,
    this.enabled = true,
  });

  /// List of items to display
  final List<T> items;
  
  /// Currently selected value (null for "All")
  final T? value;
  
  /// Callback when selection changes
  final ValueChanged<T?> onChanged;
  
  /// Function to get display label from item
  final String Function(T item) itemLabel;
  
  /// Label above the dropdown
  final String? label;
  
  /// Hint text when no selection
  final String? hint;
  
  /// Whether to show search field
  final bool searchable;
  
  /// Label for the "All" option (null to hide)
  final String? allOptionLabel;
  
  /// Whether the dropdown is enabled
  final bool enabled;

  @override
  State<PremiumDropdown<T>> createState() => _PremiumDropdownState<T>();
}

class _PremiumDropdownState<T> extends State<PremiumDropdown<T>> {
  final _searchController = TextEditingController();
  List<T> _filteredItems = [];
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  @override
  void didUpdateWidget(PremiumDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _filterItems(_searchController.text);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          return widget.itemLabel(item)
              .toLowerCase()
              .contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _showPicker() {
    if (!widget.enabled) return;
    
    setState(() => _isOpen = true);
    _searchController.clear();
    _filteredItems = widget.items;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPickerSheet(),
    ).then((_) {
      setState(() => _isOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        InkWell(
          onTap: widget.enabled ? _showPicker : null,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: widget.enabled ? Colors.white : AppColors.boneLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: _isOpen ? AppColors.forest : AppColors.borderLight,
                width: _isOpen ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _getDisplayText(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: widget.value == null
                          ? AppColors.charcoalLight
                          : AppColors.charcoal,
                    ),
                  ),
                ),
                Icon(
                  _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: AppColors.charcoalLight,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getDisplayText() {
    if (widget.value == null) {
      return widget.allOptionLabel ?? widget.hint ?? 'Select...';
    }
    return widget.itemLabel(widget.value as T);
  }

  Widget _buildPickerSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Title
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  widget.label ?? 'Select',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              
              // Search field
              if (widget.searchable)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterItems,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _filterItems('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              
              const SizedBox(height: AppSpacing.sm),
              
              // Options list
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  children: [
                    // "All" option
                    if (widget.allOptionLabel != null)
                      _buildOption(
                        context,
                        label: widget.allOptionLabel!,
                        isSelected: widget.value == null,
                        onTap: () {
                          widget.onChanged(null);
                          Navigator.pop(context);
                        },
                      ),
                    
                    // Filtered items
                    ..._filteredItems.map((item) {
                      return _buildOption(
                        context,
                        label: widget.itemLabel(item),
                        isSelected: widget.value == item,
                        onTap: () {
                          widget.onChanged(item);
                          Navigator.pop(context);
                        },
                      );
                    }),
                    
                    // No results
                    if (_filteredItems.isEmpty && _searchController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          'No results found',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.charcoalLight,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? AppColors.forest : AppColors.charcoal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.forest)
          : null,
      tileColor: isSelected ? AppColors.forestLight.withOpacity(0.1) : null,
    );
  }
}
