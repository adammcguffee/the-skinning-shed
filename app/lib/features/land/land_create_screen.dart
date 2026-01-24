import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_counties.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/services/land_listing_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🏞️ LAND CREATE SCREEN - 2025 PREMIUM
class LandCreateScreen extends ConsumerStatefulWidget {
  const LandCreateScreen({super.key});

  @override
  ConsumerState<LandCreateScreen> createState() => _LandCreateScreenState();
}

class _LandCreateScreenState extends ConsumerState<LandCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _acresController = TextEditingController();
  final _contactController = TextEditingController();
  final _imagePicker = ImagePicker();

  String _listingType = 'lease'; // lease or sale
  USState? _selectedState;
  String? _selectedCounty;
  String _contactMethod = 'email';
  List<String> _selectedSpecies = [];
  List<XFile> _selectedPhotos = [];
  bool _isSubmitting = false;

  static const _speciesOptions = [
    'Whitetail',
    'Mule Deer',
    'Elk',
    'Turkey',
    'Hog',
    'Waterfowl',
    'Upland Birds',
    'Exotics',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _acresController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedPhotos = [..._selectedPhotos, ...images].take(10).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  void _toggleSpecies(String species) {
    setState(() {
      if (_selectedSpecies.contains(species)) {
        _selectedSpecies.remove(species);
      } else {
        _selectedSpecies.add(species);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a state')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final landService = ref.read(landListingServiceProvider);

      final listingId = await landService.createListing(
        type: _listingType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.tryParse(_priceController.text) ?? 0,
        acreage: double.tryParse(_acresController.text),
        stateCode: _selectedState!.code,
        stateName: _selectedState!.name,
        county: _selectedCounty,
        contactMethod: _contactMethod,
        contactValue: _contactController.text.trim(),
        speciesTags: _selectedSpecies,
        photos: _selectedPhotos,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/land/$listingId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating listing: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
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
        title: const Text('List Land'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: AppButtonPrimary(
              label: 'Post',
              onPressed: _isSubmitting ? null : _submit,
              isLoading: _isSubmitting,
              size: AppButtonSize.small,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              // Type selection
              _SectionHeader(title: 'Listing Type'),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _ListingTypeChip(
                      label: 'For Lease',
                      icon: Icons.calendar_month_outlined,
                      isSelected: _listingType == 'lease',
                      onTap: () => setState(() => _listingType = 'lease'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _ListingTypeChip(
                      label: 'For Sale',
                      icon: Icons.sell_outlined,
                      isSelected: _listingType == 'sale',
                      onTap: () => setState(() => _listingType = 'sale'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Photos section
              _SectionHeader(title: 'Photos', subtitle: 'Up to 10 photos'),
              const SizedBox(height: AppSpacing.md),
              _PhotosGrid(
                photos: _selectedPhotos,
                onAdd: _pickPhotos,
                onRemove: _removePhoto,
                maxPhotos: 10,
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Details section
              _SectionHeader(title: 'Details'),
              const SizedBox(height: AppSpacing.md),

              // Title
              AppTextField(
                controller: _titleController,
                label: 'Title',
                hint: 'Give your listing a compelling title',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Price
              AppTextField(
                controller: _priceController,
                label: _listingType == 'lease' ? 'Price per Season' : 'Total Price',
                hint: '\$0.00',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.attach_money_rounded,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter a price';
                  if (double.tryParse(v) == null) return 'Invalid price';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Acreage
              AppTextField(
                controller: _acresController,
                label: 'Acreage',
                hint: '0',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.straighten_rounded,
                suffixText: 'acres',
              ),
              const SizedBox(height: AppSpacing.lg),

              // Description
              AppTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Describe your property, amenities, and hunting opportunities...',
                maxLines: 6,
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Location section
              _SectionHeader(title: 'Location'),
              const SizedBox(height: AppSpacing.md),

              // State
              AppDropdownField<USState>(
                label: 'State',
                value: _selectedState,
                items: USStates.all
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.name),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedState = v;
                    _selectedCounty = null;
                  });
                },
                validator: (v) => v == null ? 'Please select a state' : null,
              ),
              const SizedBox(height: AppSpacing.lg),

              // County
              if (_selectedState != null)
                AppDropdownField<String>(
                  label: 'County',
                  value: _selectedCounty,
                  items: USCounties.forState(_selectedState!.code)
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCounty = v),
                ),
              const SizedBox(height: AppSpacing.xxl),

              // Game species section
              _SectionHeader(
                title: 'Game Available',
                subtitle: 'Select all that apply',
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _speciesOptions.map((species) {
                  final isSelected = _selectedSpecies.contains(species);
                  return AppChip(
                    label: species,
                    isSelected: isSelected,
                    onTap: () => _toggleSpecies(species),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Contact section
              _SectionHeader(
                title: 'Contact Info',
                subtitle: 'How should interested parties reach you?',
              ),
              const SizedBox(height: AppSpacing.md),

              // Contact method
              Row(
                children: [
                  Expanded(
                    child: _ListingTypeChip(
                      label: 'Email',
                      icon: Icons.email_outlined,
                      isSelected: _contactMethod == 'email',
                      onTap: () => setState(() => _contactMethod = 'email'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _ListingTypeChip(
                      label: 'Phone',
                      icon: Icons.phone_outlined,
                      isSelected: _contactMethod == 'phone',
                      onTap: () => setState(() => _contactMethod = 'phone'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Contact value
              AppTextField(
                controller: _contactController,
                label: _contactMethod == 'email' ? 'Email Address' : 'Phone Number',
                hint: _contactMethod == 'email'
                    ? 'your@email.com'
                    : '(555) 123-4567',
                keyboardType: _contactMethod == 'email'
                    ? TextInputType.emailAddress
                    : TextInputType.phone,
                prefixIcon: _contactMethod == 'email'
                    ? Icons.email_outlined
                    : Icons.phone_outlined,
                validator: (v) => v == null || v.isEmpty
                    ? 'Please enter contact info'
                    : null,
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                  color: AppColors.textSecondary,
                ),
          ),
      ],
    );
  }
}

class _ListingTypeChip extends StatefulWidget {
  const _ListingTypeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ListingTypeChip> createState() => _ListingTypeChipState();
}

class _ListingTypeChipState extends State<_ListingTypeChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.success.withValues(alpha: 0.1)
                : _isHovered
                    ? AppColors.surfaceHover
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: widget.isSelected ? AppColors.success : AppColors.border,
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 20,
                color:
                    widget.isSelected ? AppColors.success : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                widget.label,
                style: TextStyle(
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  color:
                      widget.isSelected ? AppColors.success : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotosGrid extends StatelessWidget {
  const _PhotosGrid({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    this.maxPhotos = 6,
  });

  final List<XFile> photos;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final int maxPhotos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length + (photos.length < maxPhotos ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index == photos.length) {
            return _AddPhotoButton(onTap: onAdd);
          }

          return _PhotoThumbnail(
            photo: photos[index],
            onRemove: () => onRemove(index),
            isFirst: index == 0,
          );
        },
      ),
    );
  }
}

class _AddPhotoButton extends StatefulWidget {
  const _AddPhotoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AddPhotoButton> createState() => _AddPhotoButtonState();
}

class _AddPhotoButtonState extends State<_AddPhotoButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: _isHovered ? AppColors.success : AppColors.border,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 32,
                color: _isHovered ? AppColors.success : AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                'Add Photo',
                style: TextStyle(
                  fontSize: 11,
                  color:
                      _isHovered ? AppColors.success : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({
    required this.photo,
    required this.onRemove,
    this.isFirst = false,
  });

  final XFile photo;
  final VoidCallback onRemove;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: isFirst ? AppColors.success : AppColors.border,
              width: isFirst ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: kIsWeb
              ? Image.network(photo.path, fit: BoxFit.cover)
              : Image.file(File(photo.path), fit: BoxFit.cover),
        ),
        if (isFirst)
          Positioned(
            bottom: 4,
            left: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Text(
                'Cover',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
