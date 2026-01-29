import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/app_colors.dart';
import '../../data/us_states.dart';
import '../../services/club_openings_service.dart';

// ════════════════════════════════════════════════════════════════════════════
// CREATE OPENING SCREEN
// ════════════════════════════════════════════════════════════════════════════

class CreateOpeningScreen extends ConsumerStatefulWidget {
  const CreateOpeningScreen({super.key});

  @override
  ConsumerState<CreateOpeningScreen> createState() => _CreateOpeningScreenState();
}

class _CreateOpeningScreenState extends ConsumerState<CreateOpeningScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rulesController = TextEditingController();
  final _priceController = TextEditingController();
  final _acresController = TextEditingController();
  final _spotsController = TextEditingController();
  final _seasonController = TextEditingController();
  final _nearestTownController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  String? _stateCode;
  String? _county;
  String _pricePeriod = 'year';
  String _contactPreferred = 'dm';
  final Set<String> _selectedGame = {};
  final Set<String> _selectedAmenities = {};
  final List<XFile> _photos = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rulesController.dispose();
    _priceController.dispose();
    _acresController.dispose();
    _spotsController.dispose();
    _seasonController.dispose();
    _nearestTownController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_stateCode == null || _county == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select state and county')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    final service = ref.read(clubOpeningsServiceProvider);

    // Parse price
    int? priceCents;
    if (_priceController.text.isNotEmpty) {
      final priceDouble = double.tryParse(_priceController.text.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (priceDouble != null) {
        priceCents = (priceDouble * 100).round();
      }
    }

    // Create opening
    final opening = await service.createOpening(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      stateCode: _stateCode!,
      county: _county!,
      rules: _rulesController.text.trim().isEmpty ? null : _rulesController.text.trim(),
      acres: int.tryParse(_acresController.text),
      game: _selectedGame.toList(),
      amenities: _selectedAmenities.toList(),
      priceCents: priceCents,
      pricePeriod: _pricePeriod,
      nearestTown: _nearestTownController.text.trim().isEmpty ? null : _nearestTownController.text.trim(),
      spotsAvailable: int.tryParse(_spotsController.text),
      season: _seasonController.text.trim().isEmpty ? null : _seasonController.text.trim(),
      contactName: _contactNameController.text.trim().isEmpty ? null : _contactNameController.text.trim(),
      contactPhone: _contactPhoneController.text.trim().isEmpty ? null : _contactPhoneController.text.trim(),
      contactPreferred: _contactPreferred,
    );

    if (opening != null && _photos.isNotEmpty) {
      // Upload photos
      final photoPaths = <String>[];
      for (final photo in _photos) {
        final bytes = await photo.readAsBytes();
        final path = await service.uploadPhoto(opening.id, bytes, photo.name);
        if (path != null) photoPaths.add(path);
      }
      // Update with photo paths
      if (photoPaths.isNotEmpty) {
        await service.updateOpening(opening.id, photoPaths: photoPaths);
      }
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (opening != null) {
        ref.invalidate(openingsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening posted!'), backgroundColor: AppColors.success),
        );
        context.pop();
        context.push('/openings/${opening.id}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create opening')),
        );
      }
    }
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (images.isNotEmpty) {
      setState(() {
        _photos.addAll(images.take(8 - _photos.length));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
        ),
        title: const Text(
          'Post Club Opening',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Post', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Title
            _SectionTitle(title: 'Basic Info', icon: Icons.info_outline_rounded),
            const SizedBox(height: 12),
            _PremiumTextField(
              controller: _titleController,
              label: 'Title *',
              hint: 'e.g., NE Arkansas Club Seeking 2 Members',
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Location
            Row(
              children: [
                Expanded(
                  child: _PremiumDropdown(
                    label: 'State *',
                    value: _stateCode,
                    items: USStates.all.map((s) => DropdownMenuItem(value: s.code, child: Text(s.code))).toList(),
                    onChanged: (v) => setState(() {
                      _stateCode = v;
                      _county = null;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _PremiumTextField(
                    controller: TextEditingController(text: _county),
                    label: 'County *',
                    hint: 'e.g., Randolph',
                    enabled: _stateCode != null,
                    onChanged: (v) => _county = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _PremiumTextField(
              controller: _nearestTownController,
              label: 'Nearest Town',
              hint: 'e.g., Pocahontas',
            ),
            const SizedBox(height: 24),

            // Price
            _SectionTitle(title: 'Membership Details', icon: Icons.attach_money_rounded),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PremiumTextField(
                    controller: _priceController,
                    label: 'Price',
                    hint: '1500',
                    keyboardType: TextInputType.number,
                    prefix: '\$ ',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PremiumDropdown(
                    label: 'Period',
                    value: _pricePeriod,
                    items: const [
                      DropdownMenuItem(value: 'year', child: Text('Per Year')),
                      DropdownMenuItem(value: 'season', child: Text('Per Season')),
                      DropdownMenuItem(value: 'month', child: Text('Per Month')),
                      DropdownMenuItem(value: 'weekend', child: Text('Per Weekend')),
                      DropdownMenuItem(value: 'one_time', child: Text('One-Time')),
                    ],
                    onChanged: (v) => setState(() => _pricePeriod = v ?? 'year'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _PremiumTextField(
                    controller: _spotsController,
                    label: 'Spots Available',
                    hint: '2',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PremiumTextField(
                    controller: _acresController,
                    label: 'Acres',
                    hint: '1200',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PremiumTextField(
                    controller: _seasonController,
                    label: 'Season',
                    hint: '2026',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Game
            _SectionTitle(title: 'Game Types', icon: Icons.pets_rounded),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['whitetail', 'turkey', 'duck', 'hog', 'other'].map((g) {
                final selected = _selectedGame.contains(g);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedGame.remove(g);
                    } else {
                      _selectedGame.add(g);
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppColors.accent : AppColors.border,
                        width: selected ? 1.5 : 0.5,
                      ),
                    ),
                    child: Text(
                      g[0].toUpperCase() + g.substring(1),
                      style: TextStyle(
                        color: selected ? AppColors.accent : AppColors.textSecondary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Amenities
            _SectionTitle(title: 'Amenities', icon: Icons.home_rounded),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['camp', 'electric', 'water', 'lodging'].map((a) {
                final selected = _selectedAmenities.contains(a);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedAmenities.remove(a);
                    } else {
                      _selectedAmenities.add(a);
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.success.withValues(alpha: 0.15) : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppColors.success : AppColors.border,
                        width: selected ? 1.5 : 0.5,
                      ),
                    ),
                    child: Text(
                      a[0].toUpperCase() + a.substring(1),
                      style: TextStyle(
                        color: selected ? AppColors.success : AppColors.textSecondary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Description
            _SectionTitle(title: 'Description', icon: Icons.description_rounded),
            const SizedBox(height: 12),
            _PremiumTextField(
              controller: _descriptionController,
              label: 'Description *',
              hint: 'Describe your club, what makes it special, expectations...',
              maxLines: 5,
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _PremiumTextField(
              controller: _rulesController,
              label: 'Club Rules',
              hint: 'Key rules members should know...',
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Photos
            _SectionTitle(title: 'Photos', icon: Icons.photo_library_rounded),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _photos.length < 8 ? _pickPhotos : null,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_photo_alternate_rounded,
                      color: _photos.length < 8 ? AppColors.primary : AppColors.textTertiary,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _photos.isEmpty ? 'Add photos (optional)' : '${_photos.length}/8 photos selected',
                      style: TextStyle(
                        color: _photos.length < 8 ? AppColors.primary : AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  itemBuilder: (context, index) => Stack(
                    children: [
                      Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: FutureBuilder<List<int>>(
                          future: _photos[index].readAsBytes(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.memory(
                                snapshot.data! as dynamic,
                                fit: BoxFit.cover,
                              );
                            }
                            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                          },
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => setState(() => _photos.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Contact
            _SectionTitle(title: 'Contact Preferences', icon: Icons.contact_phone_rounded),
            const SizedBox(height: 12),
            _PremiumDropdown(
              label: 'Preferred Contact Method',
              value: _contactPreferred,
              items: const [
                DropdownMenuItem(value: 'dm', child: Text('In-App Message Only')),
                DropdownMenuItem(value: 'phone', child: Text('Phone Only')),
                DropdownMenuItem(value: 'both', child: Text('Both Message & Phone')),
              ],
              onChanged: (v) => setState(() => _contactPreferred = v ?? 'dm'),
            ),
            const SizedBox(height: 16),
            _PremiumTextField(
              controller: _contactNameController,
              label: 'Contact Name',
              hint: 'Your name',
            ),
            if (_contactPreferred != 'dm') ...[
              const SizedBox(height: 16),
              _PremiumTextField(
                controller: _contactPhoneController,
                label: 'Phone Number',
                hint: '555-123-4567',
                keyboardType: TextInputType.phone,
              ),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your phone will be visible to all users. Only share if comfortable.',
                        style: TextStyle(color: AppColors.warning, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),

            // Submit button
            GestureDetector(
              onTap: _isSubmitting ? null : _submit,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _isSubmitting ? AppColors.primary.withValues(alpha: 0.5) : AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isSubmitting
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Post Opening',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PremiumTextField extends StatelessWidget {
  const _PremiumTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
    this.prefix,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? prefix;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          keyboardType: keyboardType,
          enabled: enabled,
          onChanged: onChanged,
          style: TextStyle(color: enabled ? AppColors.textPrimary : AppColors.textTertiary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            prefixText: prefix,
            filled: true,
            fillColor: enabled ? AppColors.surface : AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _PremiumDropdown extends StatelessWidget {
  const _PremiumDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textTertiary),
              dropdownColor: AppColors.surfaceElevated,
              style: const TextStyle(color: AppColors.textPrimary),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
