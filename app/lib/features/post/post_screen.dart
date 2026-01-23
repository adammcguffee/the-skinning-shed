import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../data/us_counties.dart';
import '../../data/us_states.dart';
import '../../shared/widgets/widgets.dart';

/// Post trophy screen - create a new trophy post.
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
  
  // Photo handling
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
          // Limit to 5 photos
          if (_selectedPhotos.length > 5) {
            _selectedPhotos.removeRange(5, _selectedPhotos.length);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick images: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_selectedCategory == null || _selectedState == null || _harvestDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // TODO: Actually create trophy with Supabase and upload photos
    await Future.delayed(const Duration(seconds: 1));

    setState(() => _isLoading = false);

    if (mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Trophy posted successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Post Trophy'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Post',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // Photo upload section
          _PhotoUploadSection(
            photos: _selectedPhotos,
            onAddPhotos: _pickPhotos,
            onRemovePhoto: _removePhoto,
          ),
          const SizedBox(height: AppSpacing.xl),
          
          // Category selection
          PremiumDropdown<String>(
            label: 'Category *',
            items: _categories,
            value: _selectedCategory,
            onChanged: (value) {
              setState(() => _selectedCategory = value);
            },
            itemLabel: (item) => item,
            hint: 'Select species category',
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // State selection - with search
          _buildStateDropdown(),
          const SizedBox(height: AppSpacing.lg),
          
          // County selection
          _buildCountyDropdown(),
          const SizedBox(height: AppSpacing.lg),
          
          // Harvest date
          _buildDatePicker(),
          const SizedBox(height: AppSpacing.lg),
          
          // Story
          TextField(
            controller: _storyController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Story (optional)',
              hintText: 'Share the story behind this trophy...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          
          // Species-specific stats placeholder
          _buildStatsSection(),
          const SizedBox(height: AppSpacing.xxxl),
          
          // Submit button
          PremiumButton(
            label: 'Post Trophy',
            onPressed: _submit,
            isLoading: _isLoading,
            isExpanded: true,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildStateDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'State *',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: () => _showStateSelector(),
          borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedState?.name ?? 'Select state',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: _selectedState == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showStateSelector() async {
    final selected = await showModalBottomSheet<USState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchableStateSheet(
        selectedState: _selectedState,
      ),
    );
    
    if (selected != null && selected != _selectedState) {
      setState(() {
        _selectedState = selected;
        _selectedCounty = null; // Reset county when state changes
      });
    }
  }

  Widget _buildCountyDropdown() {
    final counties = _availableCounties;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'County *',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: _selectedState == null ? null : () => _showCountySelector(),
          borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: _selectedState == null 
                  ? AppColors.surfaceAlt 
                  : Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedState == null
                        ? 'Select state first'
                        : _selectedCounty ?? 'Select county',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: _selectedCounty == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: _selectedState == null 
                      ? AppColors.border 
                      : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_selectedState != null && counties.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'County data loading...',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  Future<void> _showCountySelector() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchableCountySheet(
        counties: _availableCounties,
        selectedCounty: _selectedCounty,
        stateName: _selectedState?.name ?? '',
      ),
    );
    
    if (selected != null) {
      setState(() => _selectedCounty = selected);
    }
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Harvest Date *',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: _selectDate,
          borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, 
                     color: AppColors.textSecondary, size: 20),
                const SizedBox(width: AppSpacing.md),
                Text(
                  _harvestDate != null
                      ? '${_harvestDate!.month}/${_harvestDate!.day}/${_harvestDate!.year}'
                      : 'Select date',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: _harvestDate == null
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, 
                   color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Species Stats',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _selectedCategory != null
                ? 'Add ${_selectedCategory!}-specific stats like score, weight, etc.'
                : 'Select a category to see specific stat fields.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// Photo upload section with preview
class _PhotoUploadSection extends StatelessWidget {
  const _PhotoUploadSection({
    required this.photos,
    required this.onAddPhotos,
    required this.onRemovePhoto,
  });

  final List<XFile> photos;
  final VoidCallback onAddPhotos;
  final void Function(int) onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return _buildEmptyState(context);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos (${photos.length}/5)',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length + (photos.length < 5 ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == photos.length) {
                return _buildAddButton(context);
              }
              return _buildPhotoTile(context, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border,
          width: 2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAddPhotos,
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_a_photo_rounded,
                    size: 28,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Add Photos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to select trophy photos',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoTile(BuildContext context, int index) {
    final photo = photos[index];
    
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: kIsWeb
                ? Image.network(
                    photo.path,
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 140,
                      height: 140,
                      color: AppColors.surfaceAlt,
                      child: Icon(Icons.image, color: AppColors.textSecondary),
                    ),
                  )
                : Image.file(
                    File(photo.path),
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => onRemovePhoto(index),
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          if (index == 0)
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Cover',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAddPhotos,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                size: 32,
                color: AppColors.primary,
              ),
              const SizedBox(height: 4),
              Text(
                'Add More',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Searchable state selector sheet
class _SearchableStateSheet extends StatefulWidget {
  const _SearchableStateSheet({this.selectedState});

  final USState? selectedState;

  @override
  State<_SearchableStateSheet> createState() => _SearchableStateSheetState();
}

class _SearchableStateSheetState extends State<_SearchableStateSheet> {
  final _searchController = TextEditingController();
  List<USState> _filteredStates = USStates.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterStates(String query) {
    setState(() {
      _filteredStates = USStates.search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Title
              Text(
                'Select State',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterStates,
                  decoration: InputDecoration(
                    hintText: 'Search states...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterStates('');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // States list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _filteredStates.length,
                  itemBuilder: (context, index) {
                    final state = _filteredStates[index];
                    final isSelected = state == widget.selectedState;
                    
                    return ListTile(
                      title: Text(state.name),
                      subtitle: Text(state.code),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: AppColors.primary)
                          : null,
                      selected: isSelected,
                      onTap: () => Navigator.pop(context, state),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Searchable county selector sheet
class _SearchableCountySheet extends StatefulWidget {
  const _SearchableCountySheet({
    required this.counties,
    required this.selectedCounty,
    required this.stateName,
  });

  final List<String> counties;
  final String? selectedCounty;
  final String stateName;

  @override
  State<_SearchableCountySheet> createState() => _SearchableCountySheetState();
}

class _SearchableCountySheetState extends State<_SearchableCountySheet> {
  final _searchController = TextEditingController();
  late List<String> _filteredCounties;

  @override
  void initState() {
    super.initState();
    _filteredCounties = widget.counties;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCounties(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCounties = widget.counties;
      } else {
        _filteredCounties = widget.counties
            .where((c) => c.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Title
              Text(
                'Select County',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                widget.stateName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              
              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterCounties,
                  decoration: InputDecoration(
                    hintText: 'Search counties...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterCounties('');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Counties list
              Expanded(
                child: _filteredCounties.isEmpty
                    ? Center(
                        child: Text(
                          'No counties found',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filteredCounties.length,
                        itemBuilder: (context, index) {
                          final county = _filteredCounties[index];
                          final isSelected = county == widget.selectedCounty;
                          
                          return ListTile(
                            title: Text(county),
                            trailing: isSelected
                                ? Icon(Icons.check_circle, color: AppColors.primary)
                                : null,
                            selected: isSelected,
                            onTap: () => Navigator.pop(context, county),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
