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
import 'package:shed/services/supabase_service.dart';
import 'package:shed/services/swap_shop_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🛒 SWAP SHOP EDIT SCREEN - Edit existing listing
class SwapShopEditScreen extends ConsumerStatefulWidget {
  const SwapShopEditScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<SwapShopEditScreen> createState() => _SwapShopEditScreenState();
}

class _SwapShopEditScreenState extends ConsumerState<SwapShopEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _contactController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  SwapShopListing? _listing;

  String? _selectedCategory;
  String? _selectedCondition;
  USState? _selectedState;
  String? _selectedCounty;
  String _contactMethod = 'email';

  // Existing photos from DB
  List<String> _existingPhotos = [];
  // New photos to add
  List<XFile> _newPhotos = [];
  // Photos marked for deletion
  final Set<String> _photosToDelete = {};

  static const _categories = [
    'Firearms',
    'Bows & Archery',
    'Ammunition',
    'Optics',
    'Clothing & Apparel',
    'Camping & Gear',
    'Boats & Watercraft',
    'ATVs & Vehicles',
    'Decoys & Calls',
    'Other',
  ];

  static const _conditions = [
    'New',
    'Like New',
    'Very Good',
    'Good',
    'Fair',
  ];

  @override
  void initState() {
    super.initState();
    _loadListing();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _loadListing() async {
    try {
      final service = ref.read(swapShopServiceProvider);
      final listing = await service.fetchListing(widget.listingId);

      if (listing == null) {
        setState(() {
          _error = 'Listing not found';
          _isLoading = false;
        });
        return;
      }

      // Check ownership
      final currentUserId = ref.read(currentUserProvider)?.id;
      if (listing.userId != currentUserId) {
        setState(() {
          _error = 'You can only edit your own listings';
          _isLoading = false;
        });
        return;
      }

      // Populate form fields
      _listing = listing;
      _titleController.text = listing.title;
      _descriptionController.text = listing.description ?? '';
      _priceController.text = listing.price?.toStringAsFixed(0) ?? '';
      _contactController.text = listing.contactValue;
      _selectedCategory = listing.category;
      _selectedCondition = listing.condition;
      _contactMethod = listing.contactMethod;

      // Parse state
      _selectedState = USStates.all.firstWhere(
        (s) => s.code == listing.state || s.name == listing.state,
        orElse: () => USStates.all.first,
      );
      _selectedCounty = listing.county;

      // Load existing photos
      _existingPhotos = listing.photos;

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        final totalPhotos = _existingPhotos.length - _photosToDelete.length + _newPhotos.length;
        final remaining = 6 - totalPhotos;
        setState(() {
          _newPhotos = [..._newPhotos, ...images.take(remaining)].toList();
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

  void _removeExistingPhoto(String path) {
    setState(() {
      _photosToDelete.add(path);
    });
  }

  void _removeNewPhoto(int index) {
    setState(() {
      _newPhotos.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    if (_selectedState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a state')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final service = ref.read(swapShopServiceProvider);

      // 1. Update listing fields
      await service.updateListing(
        listingId: widget.listingId,
        category: _selectedCategory,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.tryParse(_priceController.text),
        condition: _selectedCondition,
        state: _selectedState!.code,
        county: _selectedCounty,
        contactMethod: _contactMethod,
        contactValue: _contactController.text.trim(),
      );

      // 2. Delete photos marked for deletion
      for (final path in _photosToDelete) {
        await service.deleteListingPhoto(
          listingId: widget.listingId,
          photoPath: path,
        );
      }

      // 3. Upload new photos
      final activeExisting = _existingPhotos.where((p) => !_photosToDelete.contains(p)).length;
      for (int i = 0; i < _newPhotos.length; i++) {
        await service.addListingPhoto(
          listingId: widget.listingId,
          photo: _newPhotos[i],
          sortOrder: activeExisting + i,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing updated!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating listing: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.accent)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            PageHeader(title: 'Edit Listing', subtitle: 'Error'),
            Expanded(
              child: AppErrorState(message: _error!, onRetry: () => context.pop()),
            ),
          ],
        ),
      );
    }

    final service = ref.read(swapShopServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            PageHeader(
              title: 'Edit Listing',
              subtitle: 'Swap Shop',
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: AppButtonPrimary(
                    label: 'Save',
                    onPressed: _isSaving ? null : _save,
                    isLoading: _isSaving,
                    size: AppButtonSize.small,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  children: [
                    // Photos section
                    _SectionHeader(title: 'Photos', subtitle: 'Up to 6 photos'),
                    const SizedBox(height: AppSpacing.md),
                    _PhotosSection(
                      existingPhotos: _existingPhotos,
                      photosToDelete: _photosToDelete,
                      newPhotos: _newPhotos,
                      onAdd: _pickPhotos,
                      onRemoveExisting: _removeExistingPhoto,
                      onRemoveNew: _removeNewPhoto,
                      getPhotoUrl: service.getPhotoUrl,
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Details section
                    _SectionHeader(title: 'Details'),
                    const SizedBox(height: AppSpacing.md),

                    // Category
                    AppDropdownField<String>(
                      label: 'Category',
                      value: _selectedCategory,
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v),
                      validator: (v) => v == null ? 'Please select a category' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Title
                    AppTextField(
                      controller: _titleController,
                      label: 'Title',
                      hint: 'What are you selling?',
                      validator: (v) => v == null || v.isEmpty ? 'Please enter a title' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Price
                    AppTextField(
                      controller: _priceController,
                      label: 'Price',
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

                    // Condition
                    AppDropdownField<String>(
                      label: 'Condition',
                      value: _selectedCondition,
                      items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedCondition = v),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Description
                    AppTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Describe your item...',
                      maxLines: 4,
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Location section
                    _SectionHeader(title: 'Location'),
                    const SizedBox(height: AppSpacing.md),

                    // State
                    AppDropdownField<USState>(
                      label: 'State',
                      value: _selectedState,
                      items: USStates.all.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
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
                        label: 'County (optional)',
                        value: _selectedCounty,
                        items: USCounties.forState(_selectedState!.code)
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCounty = v),
                      ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Contact section
                    _SectionHeader(title: 'Contact Info', subtitle: 'How should buyers reach you?'),
                    const SizedBox(height: AppSpacing.md),

                    // Contact method
                    Row(
                      children: [
                        Expanded(
                          child: _ContactMethodChip(
                            label: 'Email',
                            icon: Icons.email_outlined,
                            isSelected: _contactMethod == 'email',
                            onTap: () => setState(() => _contactMethod = 'email'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _ContactMethodChip(
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
                      hint: _contactMethod == 'email' ? 'your@email.com' : '(555) 123-4567',
                      keyboardType:
                          _contactMethod == 'email' ? TextInputType.emailAddress : TextInputType.phone,
                      prefixIcon: _contactMethod == 'email' ? Icons.email_outlined : Icons.phone_outlined,
                      validator: (v) => v == null || v.isEmpty ? 'Please enter contact info' : null,
                    ),

                    const SizedBox(height: AppSpacing.xxxl),

                    // Save button
                    AppButtonPrimary(
                      label: 'Save Changes',
                      onPressed: _isSaving ? null : _save,
                      isLoading: _isSaving,
                      isExpanded: true,
                      size: AppButtonSize.large,
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        if (subtitle != null)
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _PhotosSection extends StatelessWidget {
  const _PhotosSection({
    required this.existingPhotos,
    required this.photosToDelete,
    required this.newPhotos,
    required this.onAdd,
    required this.onRemoveExisting,
    required this.onRemoveNew,
    required this.getPhotoUrl,
  });

  final List<String> existingPhotos;
  final Set<String> photosToDelete;
  final List<XFile> newPhotos;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemoveExisting;
  final ValueChanged<int> onRemoveNew;
  final String Function(String) getPhotoUrl;

  @override
  Widget build(BuildContext context) {
    final activeExisting = existingPhotos.where((p) => !photosToDelete.contains(p)).toList();
    final totalPhotos = activeExisting.length + newPhotos.length;

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: totalPhotos + (totalPhotos < 6 ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          // Existing photos
          if (index < activeExisting.length) {
            return _ExistingPhotoThumbnail(
              url: getPhotoUrl(activeExisting[index]),
              onRemove: () => onRemoveExisting(activeExisting[index]),
            );
          }

          // New photos
          final newIndex = index - activeExisting.length;
          if (newIndex < newPhotos.length) {
            return _NewPhotoThumbnail(
              photo: newPhotos[newIndex],
              onRemove: () => onRemoveNew(newIndex),
            );
          }

          // Add button
          return _AddPhotoButton(onTap: onAdd);
        },
      ),
    );
  }
}

class _ExistingPhotoThumbnail extends StatelessWidget {
  const _ExistingPhotoThumbnail({required this.url, required this.onRemove});

  final String url;
  final VoidCallback onRemove;

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
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder()),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.backgroundAlt,
        child: const Icon(Icons.image_outlined, color: AppColors.textTertiary),
      );
}

class _NewPhotoThumbnail extends StatelessWidget {
  const _NewPhotoThumbnail({required this.photo, required this.onRemove});

  final XFile photo;
  final VoidCallback onRemove;

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
            border: Border.all(color: AppColors.accent, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: kIsWeb
              ? Image.network(photo.path, fit: BoxFit.cover)
              : Image.file(File(photo.path), fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
            ),
          ),
        ),
        // "New" badge
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(4)),
            child: const Text('NEW', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
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
            color: _isHovered ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: _isHovered ? AppColors.primary : AppColors.border, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined, size: 32,
                  color: _isHovered ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(height: 4),
              Text('Add Photo', style: TextStyle(fontSize: 11,
                  color: _isHovered ? AppColors.primary : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactMethodChip extends StatelessWidget {
  const _ContactMethodChip({
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 2 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            )),
          ],
        ),
      ),
    );
  }
}
