import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/services/trophy_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 📝 POST TROPHY SCREEN - 2025 PREMIUM
///
/// Modern form with clear step hierarchy.
class PostScreen extends ConsumerStatefulWidget {
  const PostScreen({super.key});

  @override
  ConsumerState<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends ConsumerState<PostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _selectedSpecies;
  USState? _selectedState;
  String? _selectedCounty;
  DateTime _harvestDate = DateTime.now();
  List<XFile> _selectedPhotos = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    try {
      final photos = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (photos.isNotEmpty) {
        setState(() {
          _selectedPhotos = [..._selectedPhotos, ...photos].take(5).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick photos: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSpecies == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a species')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final trophyService = ref.read(trophyServiceProvider);
      await trophyService.createTrophy(
        category: _selectedSpecies!,
        state: _selectedState?.name ?? '',
        county: _selectedCounty ?? '',
        harvestDate: _harvestDate,
        story: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (mounted) {
        context.go('/');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trophy posted successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post: $e')),
      );
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
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Post Trophy'),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  // Photo section
                  _PhotoSection(
                    photos: _selectedPhotos,
                    onAddPhotos: _pickPhotos,
                    onRemovePhoto: (index) {
                      setState(() {
                        _selectedPhotos.removeAt(index);
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Title
                  _FormSection(
                    title: 'Title',
                    child: TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'Give your trophy a title',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Title is required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Species
                  _FormSection(
                    title: 'Species',
                    child: _SpeciesSelector(
                      selectedSpecies: _selectedSpecies,
                      onChanged: (species) {
                        setState(() => _selectedSpecies = species);
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Location
                  _FormSection(
                    title: 'Location',
                    child: LocationSelector(
                      selectedState: _selectedState,
                      selectedCounty: _selectedCounty,
                      onStateChanged: (state) {
                        setState(() {
                          _selectedState = state;
                          _selectedCounty = null;
                        });
                      },
                      onCountyChanged: (county) {
                        setState(() => _selectedCounty = county);
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Date
                  _FormSection(
                    title: 'Harvest Date',
                    child: _DatePicker(
                      date: _harvestDate,
                      onChanged: (date) {
                        setState(() => _harvestDate = date);
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Notes
                  _FormSection(
                    title: 'Notes (Optional)',
                    child: TextFormField(
                      controller: _notesController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Share the story behind your harvest...',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),

                  // Submit button (mobile)
                  AppButtonPrimary(
                    label: 'Post Trophy',
                    onPressed: _isSubmitting ? null : _submit,
                    isLoading: _isSubmitting,
                    isExpanded: true,
                    size: AppButtonSize.large,
                  ),
                  const SizedBox(height: AppSpacing.xxxxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.photos,
    required this.onAddPhotos,
    required this.onRemovePhoto,
  });

  final List<XFile> photos;
  final VoidCallback onAddPhotos;
  final ValueChanged<int> onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_library_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Photos',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                '${photos.length}/5',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (photos.isEmpty)
            _AddPhotoButton(onTap: onAddPhotos)
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                ...photos.asMap().entries.map((entry) => _PhotoThumbnail(
                      photo: entry.value,
                      onRemove: () => onRemovePhoto(entry.key),
                    )),
                if (photos.length < 5)
                  _AddPhotoButton(onTap: onAddPhotos, isSmall: true),
              ],
            ),
        ],
      ),
    );
  }
}

class _AddPhotoButton extends StatefulWidget {
  const _AddPhotoButton({
    required this.onTap,
    this.isSmall = false,
  });

  final VoidCallback onTap;
  final bool isSmall;

  @override
  State<_AddPhotoButton> createState() => _AddPhotoButtonState();
}

class _AddPhotoButtonState extends State<_AddPhotoButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.isSmall ? 80.0 : 120.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.isSmall ? size : double.infinity,
          height: size,
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : AppColors.backgroundAlt,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: _isHovered ? AppColors.primary : AppColors.border,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: widget.isSmall ? 24 : 32,
                color: _isHovered ? AppColors.primary : AppColors.textTertiary,
              ),
              if (!widget.isSmall) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Add Photos',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _isHovered ? AppColors.primary : AppColors.textSecondary,
                      ),
                ),
              ],
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
  });

  final XFile photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: FutureBuilder<dynamic>(
            future: photo.readAsBytes(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                );
              }
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            },
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
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
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

class _SpeciesSelector extends StatelessWidget {
  const _SpeciesSelector({
    required this.selectedSpecies,
    required this.onChanged,
  });

  final String? selectedSpecies;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final species = [
      ('deer', 'Whitetail Deer', AppColors.categoryDeer),
      ('turkey', 'Turkey', AppColors.categoryTurkey),
      ('bass', 'Largemouth Bass', AppColors.categoryBass),
      ('other_game', 'Other Game', AppColors.categoryOtherGame),
      ('other_fishing', 'Other Fishing', AppColors.categoryOtherFishing),
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: species.map((s) {
        final isSelected = selectedSpecies == s.$1;
        return AppChip(
          label: s.$2,
          color: s.$3,
          isSelected: isSelected,
          onTap: () => onChanged(isSelected ? null : s.$1),
        );
      }).toList(),
    );
  }
}

class _DatePicker extends StatefulWidget {
  const _DatePicker({
    required this.date,
    required this.onChanged,
  });

  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  State<_DatePicker> createState() => _DatePickerState();
}

class _DatePickerState extends State<_DatePicker> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: widget.date,
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (date != null) {
            widget.onChanged(date);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: _isHovered ? AppColors.borderStrong : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '${widget.date.month}/${widget.date.day}/${widget.date.year}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
