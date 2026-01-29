import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/services/trophy_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 📝 TROPHY EDIT SCREEN - Edit existing trophy post
class TrophyEditScreen extends ConsumerStatefulWidget {
  const TrophyEditScreen({super.key, required this.trophyId});

  final String trophyId;

  @override
  ConsumerState<TrophyEditScreen> createState() => _TrophyEditScreenState();
}

class _TrophyEditScreenState extends ConsumerState<TrophyEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storyController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  Map<String, dynamic>? _trophy;

  String? _selectedCategory;
  USState? _selectedState;
  String? _selectedCounty;
  DateTime _harvestDate = DateTime.now();
  TimeOfDay? _harvestTime;
  
  // Existing photos from DB
  List<Map<String, dynamic>> _existingPhotos = [];
  // New photos to add
  List<XFile> _newPhotos = [];
  // Photos marked for deletion
  final Set<String> _photosToDelete = {};

  @override
  void initState() {
    super.initState();
    _loadTrophy();
  }

  @override
  void dispose() {
    _storyController.dispose();
    super.dispose();
  }

  Future<void> _loadTrophy() async {
    try {
      final trophyService = ref.read(trophyServiceProvider);
      final trophy = await trophyService.fetchTrophy(widget.trophyId);

      if (trophy == null) {
        setState(() {
          _error = 'Trophy not found';
          _isLoading = false;
        });
        return;
      }

      // Check ownership
      final currentUserId = ref.read(currentUserProvider)?.id;
      if (trophy['user_id'] != currentUserId) {
        setState(() {
          _error = 'You can only edit your own trophies';
          _isLoading = false;
        });
        return;
      }

      // Populate form fields
      _trophy = trophy;
      _selectedCategory = trophy['category'];
      _storyController.text = trophy['story'] ?? '';

      // Parse state
      final stateName = trophy['state'] as String?;
      if (stateName != null) {
        _selectedState = USStates.all.firstWhere(
          (s) => s.name == stateName,
          orElse: () => USStates.all.first,
        );
      }

      _selectedCounty = trophy['county'];

      // Parse harvest date
      final harvestDateStr = trophy['harvest_date'] as String?;
      if (harvestDateStr != null) {
        _harvestDate = DateTime.parse(harvestDateStr);
      }

      // Parse harvest time
      final harvestTimeStr = trophy['harvest_time'] as String?;
      if (harvestTimeStr != null) {
        final parts = harvestTimeStr.split(':');
        if (parts.length >= 2) {
          _harvestTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }

      // Load existing photos
      final photos = trophy['trophy_photos'] as List? ?? [];
      _existingPhotos = photos.cast<Map<String, dynamic>>();

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
      final photos = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (photos.isNotEmpty) {
        final totalPhotos = _existingPhotos.length - _photosToDelete.length + _newPhotos.length;
        final remaining = 5 - totalPhotos;
        setState(() {
          _newPhotos = [..._newPhotos, ...photos.take(remaining)].toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick photos: $e')),
      );
    }
  }

  void _removeExistingPhoto(String photoId) {
    setState(() {
      _photosToDelete.add(photoId);
    });
  }

  void _removeNewPhoto(int index) {
    setState(() {
      _newPhotos.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final trophyService = ref.read(trophyServiceProvider);

      // Format harvest time
      String? harvestTimeStr;
      String? harvestTimeBucket;
      if (_harvestTime != null) {
        harvestTimeStr = '${_harvestTime!.hour.toString().padLeft(2, '0')}:${_harvestTime!.minute.toString().padLeft(2, '0')}:00';
        final hour = _harvestTime!.hour;
        if (hour >= 5 && hour < 10) harvestTimeBucket = 'morning';
        else if (hour >= 10 && hour < 14) harvestTimeBucket = 'midday';
        else if (hour >= 14 && hour < 19) harvestTimeBucket = 'evening';
        else harvestTimeBucket = 'night';
      }

      // 1. Update trophy fields
      await trophyService.updateTrophy(
        trophyId: widget.trophyId,
        category: _selectedCategory,
        state: _selectedState?.name,
        county: _selectedCounty,
        harvestDate: _harvestDate,
        harvestTime: harvestTimeStr,
        harvestTimeBucket: harvestTimeBucket,
        story: _storyController.text.trim(),
      );

      // 2. Delete photos marked for deletion
      for (final photoId in _photosToDelete) {
        final photo = _existingPhotos.firstWhere(
          (p) => p['id'] == photoId,
          orElse: () => {},
        );
        if (photo.isNotEmpty) {
          await trophyService.deletePhoto(
            trophyId: widget.trophyId,
            photoId: photoId,
            storagePath: photo['storage_path'],
          );
        }
      }

      // 3. Upload new photos
      for (int i = 0; i < _newPhotos.length; i++) {
        final photo = _newPhotos[i];
        final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final bytes = await photo.readAsBytes();
        await trophyService.uploadPhotoBytes(
          trophyId: widget.trophyId,
          bytes: bytes,
          fileName: fileName,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trophy updated!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
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
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            PageHeader(title: 'Edit Trophy', subtitle: 'Error'),
            Expanded(
              child: AppErrorState(
                message: _error!,
                onRetry: () => context.pop(),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            PageHeader(
              title: 'Edit Trophy',
              subtitle: 'Update your harvest',
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
                          existingPhotos: _existingPhotos,
                          photosToDelete: _photosToDelete,
                          newPhotos: _newPhotos,
                          onAddPhotos: _pickPhotos,
                          onRemoveExisting: _removeExistingPhoto,
                          onRemoveNew: _removeNewPhoto,
                          getPhotoUrl: (path) {
                            final client = SupabaseService.instance.client;
                            return client?.storage.from('trophy_photos').getPublicUrl(path);
                          },
                        ),
                        const SizedBox(height: AppSpacing.xxl),

                        // Species
                        _FormSection(
                          title: 'Species',
                          child: _SpeciesSelector(
                            selectedSpecies: _selectedCategory,
                            onChanged: (species) {
                              setState(() => _selectedCategory = species);
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

                        // Time
                        _FormSection(
                          title: 'Harvest Time (Optional)',
                          child: _TimePicker(
                            time: _harvestTime,
                            onChanged: (time) {
                              setState(() => _harvestTime = time);
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Story
                        _FormSection(
                          title: 'Notes (Optional)',
                          child: TextFormField(
                            controller: _storyController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'Share the story behind your harvest...',
                            ),
                          ),
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
                        const SizedBox(height: AppSpacing.xxxxl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable widgets

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.existingPhotos,
    required this.photosToDelete,
    required this.newPhotos,
    required this.onAddPhotos,
    required this.onRemoveExisting,
    required this.onRemoveNew,
    required this.getPhotoUrl,
  });

  final List<Map<String, dynamic>> existingPhotos;
  final Set<String> photosToDelete;
  final List<XFile> newPhotos;
  final VoidCallback onAddPhotos;
  final ValueChanged<String> onRemoveExisting;
  final ValueChanged<int> onRemoveNew;
  final String? Function(String) getPhotoUrl;

  @override
  Widget build(BuildContext context) {
    final activeExisting = existingPhotos.where((p) => !photosToDelete.contains(p['id'])).toList();
    final totalPhotos = activeExisting.length + newPhotos.length;

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
              const Icon(Icons.photo_library_outlined, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text('Photos', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text('$totalPhotos/5', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              // Existing photos
              ...activeExisting.map((photo) {
                final url = getPhotoUrl(photo['storage_path'] as String);
                return _ExistingPhotoThumbnail(
                  url: url,
                  onRemove: () => onRemoveExisting(photo['id'] as String),
                );
              }),
              // New photos
              ...newPhotos.asMap().entries.map((entry) => _NewPhotoThumbnail(
                    photo: entry.value,
                    onRemove: () => onRemoveNew(entry.key),
                  )),
              // Add button
              if (totalPhotos < 5) _AddPhotoButton(onTap: onAddPhotos),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExistingPhotoThumbnail extends StatelessWidget {
  const _ExistingPhotoThumbnail({required this.url, required this.onRemove});

  final String? url;
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
          child: url != null
              ? Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
              : _placeholder(),
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
                borderRadius: BorderRadius.circular(12),
              ),
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
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.accent, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: FutureBuilder<dynamic>(
            future: photo.readAsBytes(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Image.memory(snapshot.data!, fit: BoxFit.cover);
              }
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
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
                color: AppColors.error,
                borderRadius: BorderRadius.circular(12),
              ),
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
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(4),
            ),
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
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : AppColors.backgroundAlt,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: _isHovered ? AppColors.primary : AppColors.border),
          ),
          child: Icon(
            Icons.add_photo_alternate_outlined,
            size: 24,
            color: _isHovered ? AppColors.primary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _SpeciesSelector extends StatelessWidget {
  const _SpeciesSelector({required this.selectedSpecies, required this.onChanged});

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
  const _DatePicker({required this.date, required this.onChanged});

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
          if (date != null) widget.onChanged(date);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: _isHovered ? AppColors.borderStrong : AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Text('${widget.date.month}/${widget.date.day}/${widget.date.year}',
                  style: Theme.of(context).textTheme.bodyLarge),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimePicker extends StatefulWidget {
  const _TimePicker({required this.time, required this.onChanged});

  final TimeOfDay? time;
  final ValueChanged<TimeOfDay?> onChanged;

  @override
  State<_TimePicker> createState() => _TimePickerState();
}

class _TimePickerState extends State<_TimePicker> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final time = await showTimePicker(
            context: context,
            initialTime: widget.time ?? TimeOfDay.now(),
          );
          if (time != null) widget.onChanged(time);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: _isHovered ? AppColors.borderStrong : AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Text(
                widget.time != null ? widget.time!.format(context) : 'Tap to set time',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: widget.time != null ? AppColors.textPrimary : AppColors.textTertiary,
                    ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
