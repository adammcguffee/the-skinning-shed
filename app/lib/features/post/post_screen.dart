import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../data/us_counties.dart';
import '../../data/us_states.dart';
import '../../shared/widgets/animated_entry.dart';

/// 📝 MODERN POST TROPHY SCREEN
/// 
/// Features:
/// - Clear step hierarchy
/// - Modern dropdown sheets with search
/// - Photo picker with preview grid
/// - Anchored, obvious CTA
class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  String? _selectedCategory;
  USState? _selectedState;
  String? _selectedCounty;
  DateTime? _harvestDate;
  final _storyController = TextEditingController();
  bool _isLoading = false;

  final _imagePicker = ImagePicker();
  final List<XFile> _selectedPhotos = [];
  final _categories = ['Deer', 'Turkey', 'Bass', 'Other Game', 'Other Fishing'];

  @override
  void dispose() {
    _storyController.dispose();
    super.dispose();
  }

  List<String> get _availableCounties {
    if (_selectedState == null) return [];
    return USCounties.forState(_selectedState!.code);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _harvestDate = picked);
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (images.isNotEmpty) {
        setState(() {
          _selectedPhotos.addAll(images);
          if (_selectedPhotos.length > 5) {
            _selectedPhotos.removeRange(5, _selectedPhotos.length);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick images: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() => _selectedPhotos.removeAt(index));
  }

  Future<void> _submit() async {
    if (_selectedCategory == null || _selectedState == null || _harvestDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);

    if (mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trophy posted successfully!'), backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Post Trophy',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress indicator
          _StepIndicator(
            currentStep: _calculateStep(),
            totalSteps: 4,
          ),
          // Form content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Step 1: Photos
                AnimatedEntry(
                  child: _SectionCard(
                  number: 1,
                  title: 'Add Photos',
                  subtitle: 'Up to 5 photos',
                  isComplete: _selectedPhotos.isNotEmpty,
                  child: _PhotoGrid(
                    photos: _selectedPhotos,
                    onAddPhotos: _pickPhotos,
                    onRemovePhoto: _removePhoto,
                  ),
                  ),
                ),
                const SizedBox(height: 16),

                // Step 2: Category
                AnimatedEntry(
                  delay: const Duration(milliseconds: 60),
                  child: _SectionCard(
                  number: 2,
                  title: 'Species Category',
                  isComplete: _selectedCategory != null,
                  child: _CategorySelector(
                    selected: _selectedCategory,
                    onChanged: (v) => setState(() => _selectedCategory = v),
                  ),
                  ),
                ),
                const SizedBox(height: 16),

                // Step 3: Location
                AnimatedEntry(
                  delay: const Duration(milliseconds: 120),
                  child: _SectionCard(
                  number: 3,
                  title: 'Location',
                  subtitle: 'County level only - we respect your privacy',
                  isComplete: _selectedState != null && _selectedCounty != null,
                  child: Column(
                    children: [
                      _SelectField(
                        label: 'State',
                        value: _selectedState?.name,
                        hint: 'Select state',
                        onTap: _showStateSelector,
                      ),
                      const SizedBox(height: 12),
                      _SelectField(
                        label: 'County',
                        value: _selectedCounty,
                        hint: _selectedState == null ? 'Select state first' : 'Select county',
                        enabled: _selectedState != null,
                        onTap: _showCountySelector,
                      ),
                    ],
                  ),
                  ),
                ),
                const SizedBox(height: 16),

                // Step 4: Date & Story
                AnimatedEntry(
                  delay: const Duration(milliseconds: 180),
                  child: _SectionCard(
                  number: 4,
                  title: 'Details',
                  isComplete: _harvestDate != null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SelectField(
                        label: 'Harvest Date',
                        value: _harvestDate != null
                            ? '${_harvestDate!.month}/${_harvestDate!.day}/${_harvestDate!.year}'
                            : null,
                        hint: 'Select date',
                        icon: Icons.calendar_today_rounded,
                        onTap: _selectDate,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Story (optional)',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _storyController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Share the story behind this trophy...',
                          filled: true,
                          fillColor: AppColors.surfaceAlt,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          // Submit button
          _SubmitBar(
            isLoading: _isLoading,
            isEnabled: _canSubmit,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }

  int _calculateStep() {
    if (_selectedPhotos.isEmpty) return 1;
    if (_selectedCategory == null) return 2;
    if (_selectedState == null || _selectedCounty == null) return 3;
    return 4;
  }

  bool get _canSubmit =>
      _selectedPhotos.isNotEmpty &&
      _selectedCategory != null &&
      _selectedState != null &&
      _selectedCounty != null &&
      _harvestDate != null;

  Future<void> _showStateSelector() async {
    final selected = await showModalBottomSheet<USState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchableSheet<USState>(
        title: 'Select State',
        items: USStates.all,
        selected: _selectedState,
        itemLabel: (s) => s.name,
        searchFilter: (s, q) => s.name.toLowerCase().contains(q.toLowerCase()),
      ),
    );
    if (selected != null && selected != _selectedState) {
      setState(() {
        _selectedState = selected;
        _selectedCounty = null;
      });
    }
  }

  Future<void> _showCountySelector() async {
    if (_selectedState == null) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchableSheet<String>(
        title: 'Select County',
        items: _availableCounties,
        selected: _selectedCounty,
        itemLabel: (c) => c,
        searchFilter: (c, q) => c.toLowerCase().contains(q.toLowerCase()),
      ),
    );
    if (selected != null) {
      setState(() => _selectedCounty = selected);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP INDICATOR
// ═══════════════════════════════════════════════════════════════════════════════

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep, required this.totalSteps});
  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: AppColors.surface,
      child: Row(
        children: List.generate(totalSteps * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector
            final stepBefore = (index ~/ 2) + 1;
            return Expanded(
              child: Container(
                height: 2,
                color: stepBefore < currentStep 
                    ? AppColors.primary 
                    : AppColors.border,
              ),
            );
          } else {
            // Step dot
            final step = (index ~/ 2) + 1;
            final isComplete = step < currentStep;
            final isCurrent = step == currentStep;
            return Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isComplete ? AppColors.primary 
                    : isCurrent ? AppColors.primary.withOpacity(0.15)
                    : AppColors.surfaceAlt,
                shape: BoxShape.circle,
                border: isCurrent 
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
              ),
              child: Center(
                child: isComplete
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        '$step',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isCurrent ? AppColors.primary : AppColors.textTertiary,
                        ),
                      ),
              ),
            );
          }
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.number,
    required this.title,
    required this.child,
    this.subtitle,
    this.isComplete = false,
  });

  final int number;
  final String title;
  final String? subtitle;
  final bool isComplete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete 
              ? AppColors.success.withOpacity(0.3) 
              : AppColors.border.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isComplete ? AppColors.success : AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isComplete
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '$number',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PHOTO GRID
// ═══════════════════════════════════════════════════════════════════════════════

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.onAddPhotos,
    required this.onRemovePhoto,
  });

  final List<XFile> photos;
  final VoidCallback onAddPhotos;
  final void Function(int) onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Add button
          if (photos.length < 5)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAddPhotos,
                borderRadius: BorderRadius.circular(12),
                hoverColor: AppColors.primary.withOpacity(0.06),
                splashColor: AppColors.primary.withOpacity(0.12),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Photo thumbnails
          ...photos.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _PhotoThumbnail(
                file: entry.value,
                onRemove: () => onRemovePhoto(entry.key),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({required this.file, required this.onRemove});
  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 100,
            height: 100,
            child: kIsWeb
                ? Image.network(file.path, fit: BoxFit.cover)
                : Image.file(File(file.path), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CATEGORY SELECTOR
// ═══════════════════════════════════════════════════════════════════════════════

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String> onChanged;

  static const _categories = [
    ('🦌', 'Deer', AppColors.categoryDeer),
    ('🦃', 'Turkey', AppColors.categoryTurkey),
    ('🐟', 'Bass', AppColors.categoryBass),
    ('🎯', 'Other Game', AppColors.categoryOtherGame),
    ('🎣', 'Other Fishing', AppColors.categoryOtherFishing),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final isSelected = selected == cat.$2;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(cat.$2),
            borderRadius: BorderRadius.circular(12),
            hoverColor: cat.$3.withOpacity(0.08),
            splashColor: cat.$3.withOpacity(0.12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? cat.$3.withOpacity(0.15) : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? cat.$3 : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat.$1, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    cat.$2,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? cat.$3 : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SELECT FIELD
// ═══════════════════════════════════════════════════════════════════════════════

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final String hint;
  final IconData? icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        hoverColor: AppColors.primary.withOpacity(0.06),
        splashColor: AppColors.primary.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value ?? hint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: value != null ? AppColors.textPrimary : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: enabled ? AppColors.textSecondary : AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUBMIT BAR
// ═══════════════════════════════════════════════════════════════════════════════

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.isLoading,
    required this.isEnabled,
    required this.onSubmit,
  });

  final bool isLoading;
  final bool isEnabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.5))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: isEnabled && !isLoading ? onSubmit : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'Post Trophy',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEARCHABLE SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _SearchableSheet<T> extends StatefulWidget {
  const _SearchableSheet({
    required this.title,
    required this.items,
    required this.selected,
    required this.itemLabel,
    required this.searchFilter,
  });

  final String title;
  final List<T> items;
  final T? selected;
  final String Function(T) itemLabel;
  final bool Function(T, String) searchFilter;

  @override
  State<_SearchableSheet<T>> createState() => _SearchableSheetState<T>();
}

class _SearchableSheetState<T> extends State<_SearchableSheet<T>> {
  final _searchController = TextEditingController();
  late List<T> _filteredItems;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text;
    setState(() {
      _filteredItems = query.isEmpty
          ? widget.items
          : widget.items.where((i) => widget.searchFilter(i, query)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: ListView.builder(
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final isSelected = item == widget.selected;
                return ListTile(
                  title: Text(widget.itemLabel(item)),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  tileColor: isSelected ? AppColors.primary.withOpacity(0.05) : null,
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
