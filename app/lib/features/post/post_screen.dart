import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/services/trophy_service.dart';
import 'package:shed/services/weather_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 📝 POST TROPHY SCREEN - 2025 PREMIUM
///
/// Modern form with clear step hierarchy and auto-fill weather conditions.
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
  
  // Weather/conditions controllers
  final _tempController = TextEditingController();
  final _pressureController = TextEditingController();
  final _windSpeedController = TextEditingController();
  final _humidityController = TextEditingController();

  String? _selectedSpecies;
  USState? _selectedState;
  String? _selectedCounty;
  String? _selectedCountyFips;
  DateTime _harvestDate = DateTime.now();
  TimeOfDay? _harvestTime;
  List<XFile> _selectedPhotos = [];
  bool _isSubmitting = false;
  
  // Weather/moon data
  WeatherSnapshot? _weatherSnapshot;
  MoonSnapshot? _moonSnapshot;
  bool _loadingWeather = false;
  bool _weatherEdited = false;
  String _weatherSource = 'auto';
  int? _windDirDeg;
  int? _cloudPct;
  String? _conditionText;

  @override
  void initState() {
    super.initState();
    // Initialize moon phase for current date
    final weatherService = WeatherService();
    _moonSnapshot = weatherService.getMoonPhase(_harvestDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _tempController.dispose();
    _pressureController.dispose();
    _windSpeedController.dispose();
    _humidityController.dispose();
    super.dispose();
  }
  
  /// Fetch historical weather when location and date/time are set.
  Future<void> _fetchWeatherConditions() async {
    if (_selectedState == null || _selectedCounty == null) return;
    if (_harvestTime == null) return;
    
    setState(() => _loadingWeather = true);
    
    try {
      final weatherService = WeatherService();
      
      // Combine date and time
      final dateTime = DateTime(
        _harvestDate.year,
        _harvestDate.month,
        _harvestDate.day,
        _harvestTime!.hour,
        _harvestTime!.minute,
      );
      
      // Prefer FIPS-based lookup (more reliable)
      WeatherSnapshot? weather;
      if (_selectedCountyFips != null) {
        weather = await weatherService.getHistoricalForCountyFips(
          countyFips: _selectedCountyFips!,
          dateTime: dateTime,
        );
      } else {
        // Fallback to name-based lookup
        weather = await weatherService.getHistoricalForCounty(
          stateCode: _selectedState!.code,
          county: _selectedCounty!,
          dateTime: dateTime,
        );
      }
      
      final moon = weatherService.getMoonPhase(_harvestDate);
      
      if (mounted && weather != null) {
        setState(() {
          _weatherSnapshot = weather;
          _moonSnapshot = moon;
          _weatherEdited = false;
          _weatherSource = 'auto';
          
          // Populate editable fields
          _tempController.text = weather!.tempF.round().toString();
          _pressureController.text = weather.pressureInHg.toStringAsFixed(2);
          _windSpeedController.text = weather.windSpeedMph.round().toString();
          _humidityController.text = weather.humidity.toString();
          _windDirDeg = weather.windDirDeg;
          _cloudPct = weather.cloudPct;
          _conditionText = weather.conditionText;
        });
      } else if (mounted) {
        setState(() {
          _moonSnapshot = moon;
        });
      }
    } catch (e) {
      print('Error fetching weather: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingWeather = false);
      }
    }
  }
  
  /// Called when user edits any weather field.
  void _onWeatherEdited() {
    if (!_weatherEdited && _weatherSnapshot != null) {
      setState(() {
        _weatherEdited = true;
        _weatherSource = 'mixed';
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
      
      // Build weather snapshot from form fields
      Map<String, dynamic>? weatherData;
      if (_tempController.text.isNotEmpty || _weatherSnapshot != null) {
        final tempF = double.tryParse(_tempController.text) ?? _weatherSnapshot?.tempF ?? 0;
        final pressureInHg = double.tryParse(_pressureController.text) ?? _weatherSnapshot?.pressureInHg ?? 0;
        final windSpeedMph = double.tryParse(_windSpeedController.text) ?? _weatherSnapshot?.windSpeedMph ?? 0;
        final humidity = int.tryParse(_humidityController.text) ?? _weatherSnapshot?.humidity ?? 0;
        
        weatherData = {
          'temp_f': tempF,
          'temp_c': (tempF - 32) * 5 / 9,
          'pressure_hpa': pressureInHg / 0.02953,
          'pressure_inhg': pressureInHg,
          'wind_speed': windSpeedMph,
          'wind_dir_deg': _windDirDeg ?? _weatherSnapshot?.windDirDeg ?? 0,
          'wind_dir_text': _weatherSnapshot?.windDirText ?? 'N',
          'humidity_pct': humidity,
          'cloud_pct': _cloudPct ?? _weatherSnapshot?.cloudPct ?? 0,
          'condition_text': _conditionText ?? _weatherSnapshot?.conditionText ?? 'Unknown',
          'condition_code': (_weatherSnapshot?.conditionCode ?? 0).toString(),
          'precip_mm': _weatherSnapshot?.precipMm ?? 0,
          'is_hourly': true,
          'source': _weatherSource,
        };
      }
      
      // Build moon snapshot
      Map<String, dynamic>? moonData;
      if (_moonSnapshot != null) {
        moonData = _moonSnapshot!.toJson();
      }
      
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
      
      final trophyId = await trophyService.createTrophy(
        category: _selectedSpecies!,
        state: _selectedState?.name ?? '',
        county: _selectedCounty ?? '',
        stateCode: _selectedState?.code,
        countyFips: _selectedCountyFips,
        harvestDate: _harvestDate,
        harvestTime: harvestTimeStr,
        harvestTimeBucket: harvestTimeBucket,
        story: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        weatherSnapshot: weatherData,
        moonSnapshot: moonData,
        weatherSource: _weatherSource,
        weatherEdited: _weatherEdited,
      );

      // Upload photos if trophy was created successfully
      if (trophyId != null && _selectedPhotos.isNotEmpty) {
        for (int i = 0; i < _selectedPhotos.length; i++) {
          final photo = _selectedPhotos[i];
          final fileName = 'photo_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          
          // Read bytes from XFile (cross-platform)
          final bytes = await photo.readAsBytes();
          await trophyService.uploadPhotoBytes(
            trophyId: trophyId,
            bytes: bytes,
            fileName: fileName,
          );
        }
      }

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
                      selectedCountyFips: _selectedCountyFips,
                      onStateChanged: (state) {
                        setState(() {
                          _selectedState = state;
                          _selectedCounty = null;
                          _selectedCountyFips = null;
                          _weatherSnapshot = null;
                        });
                      },
                      onCountyChanged: (county) {
                        setState(() {
                          _selectedCounty = county;
                        });
                      },
                      onCountyChangedWithFips: (county) {
                        setState(() {
                          _selectedCounty = county?.name;
                          _selectedCountyFips = county?.fips;
                        });
                        // Auto-fetch weather if time is set
                        if (_harvestTime != null) {
                          _fetchWeatherConditions();
                        }
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
                        setState(() {
                          _harvestDate = date;
                          // Update moon phase
                          final weatherService = WeatherService();
                          _moonSnapshot = weatherService.getMoonPhase(date);
                        });
                        // Auto-fetch weather if time is set
                        if (_harvestTime != null && _selectedCounty != null) {
                          _fetchWeatherConditions();
                        }
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
                        // Auto-fetch weather when time is set and we have location
                        if (_selectedCounty != null) {
                          _fetchWeatherConditions();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Conditions section (auto-filled when location+date+time are set)
                  if (_harvestTime != null && _selectedCounty != null) ...[
                    _ConditionsSection(
                      loading: _loadingWeather,
                      weather: _weatherSnapshot,
                      moon: _moonSnapshot,
                      edited: _weatherEdited,
                      tempController: _tempController,
                      pressureController: _pressureController,
                      windSpeedController: _windSpeedController,
                      humidityController: _humidityController,
                      windDirDeg: _windDirDeg,
                      cloudPct: _cloudPct,
                      conditionText: _conditionText,
                      onEdited: _onWeatherEdited,
                      onWindDirChanged: (dir) {
                        setState(() => _windDirDeg = dir);
                        _onWeatherEdited();
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

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

/// Time picker widget
class _TimePicker extends StatefulWidget {
  const _TimePicker({
    required this.time,
    required this.onChanged,
  });

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
          if (time != null) {
            widget.onChanged(time);
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
                Icons.access_time_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                widget.time != null 
                    ? widget.time!.format(context)
                    : 'Tap to set time',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: widget.time != null 
                      ? AppColors.textPrimary 
                      : AppColors.textTertiary,
                ),
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

/// Conditions section with auto-fill and editable fields.
class _ConditionsSection extends StatelessWidget {
  const _ConditionsSection({
    required this.loading,
    required this.weather,
    required this.moon,
    required this.edited,
    required this.tempController,
    required this.pressureController,
    required this.windSpeedController,
    required this.humidityController,
    required this.windDirDeg,
    required this.cloudPct,
    required this.conditionText,
    required this.onEdited,
    required this.onWindDirChanged,
  });

  final bool loading;
  final WeatherSnapshot? weather;
  final MoonSnapshot? moon;
  final bool edited;
  final TextEditingController tempController;
  final TextEditingController pressureController;
  final TextEditingController windSpeedController;
  final TextEditingController humidityController;
  final int? windDirDeg;
  final int? cloudPct;
  final String? conditionText;
  final VoidCallback onEdited;
  final ValueChanged<int?> onWindDirChanged;

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
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(
                  Icons.cloud_outlined,
                  size: 20,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Conditions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (edited)
                      const Text(
                        'Edited by you',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.accent,
                        ),
                      ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          
          // Helper text
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.backgroundAlt,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    weather != null
                        ? 'Auto-filled from historical weather. Edit if needed.'
                        : 'Could not fetch weather data. Enter manually if known.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Weather fields grid
          Row(
            children: [
              Expanded(
                child: _ConditionField(
                  label: 'Temp (°F)',
                  controller: tempController,
                  icon: Icons.thermostat_outlined,
                  onChanged: onEdited,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ConditionField(
                  label: 'Pressure (inHg)',
                  controller: pressureController,
                  icon: Icons.speed_outlined,
                  onChanged: onEdited,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _ConditionField(
                  label: 'Wind (mph)',
                  controller: windSpeedController,
                  icon: Icons.air_rounded,
                  onChanged: onEdited,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ConditionField(
                  label: 'Humidity (%)',
                  controller: humidityController,
                  icon: Icons.water_drop_outlined,
                  onChanged: onEdited,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Wind direction selector
          _WindDirectionSelector(
            selectedDeg: windDirDeg,
            onChanged: onWindDirChanged,
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Moon phase display
          if (moon != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.backgroundAlt,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(
                      _moonIcon(moon!.phaseNumber),
                      size: 22,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Moon Phase',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      Text(
                        moon!.phaseName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '${moon!.illuminationPct.round()}%',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
            ),
          
          // Condition summary
          if (conditionText != null && conditionText!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.wb_cloudy_outlined,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  conditionText!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (cloudPct != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '· $cloudPct% cloud',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _moonIcon(int phaseNumber) {
    switch (phaseNumber) {
      case 0: return Icons.brightness_1_outlined; // New Moon
      case 1: return Icons.brightness_2_rounded; // Waxing Crescent
      case 2: return Icons.brightness_5_rounded; // First Quarter
      case 3: return Icons.brightness_6_rounded; // Waxing Gibbous
      case 4: return Icons.brightness_1_rounded; // Full Moon
      case 5: return Icons.brightness_6_outlined; // Waning Gibbous
      case 6: return Icons.brightness_4_rounded; // Last Quarter
      case 7: return Icons.brightness_3_rounded; // Waning Crescent
      default: return Icons.dark_mode_outlined;
    }
  }
}

/// Individual condition input field.
class _ConditionField extends StatelessWidget {
  const _ConditionField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            filled: true,
            fillColor: AppColors.backgroundAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}

/// Wind direction selector using compass directions.
class _WindDirectionSelector extends StatelessWidget {
  const _WindDirectionSelector({
    required this.selectedDeg,
    required this.onChanged,
  });

  final int? selectedDeg;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    const directions = [
      ('N', 0),
      ('NE', 45),
      ('E', 90),
      ('SE', 135),
      ('S', 180),
      ('SW', 225),
      ('W', 270),
      ('NW', 315),
    ];

    // Find selected direction
    String? selectedDir;
    if (selectedDeg != null) {
      final normalized = ((selectedDeg! + 22) % 360) ~/ 45;
      selectedDir = directions[normalized % 8].$1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.explore_outlined, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.xs),
            const Text(
              'Wind Direction',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: directions.map((d) {
            final isSelected = selectedDir == d.$1;
            return GestureDetector(
              onTap: () => onChanged(d.$2),
              child: Container(
                width: 36,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppColors.accent.withOpacity(0.15) 
                      : AppColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : AppColors.border,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  d.$1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
