import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/widgets/widgets.dart';

/// Post trophy screen - create a new trophy post.
class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  String? _selectedCategory;
  String? _selectedState;
  String? _selectedCounty;
  DateTime? _harvestDate;
  final _storyController = TextEditingController();
  bool _isLoading = false;

  final _categories = ['Deer', 'Turkey', 'Bass', 'Other Game', 'Other Fishing'];
  final _states = ['Texas', 'Alabama', 'Florida', 'Georgia', 'Tennessee'];

  @override
  void dispose() {
    _storyController.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    if (_selectedCategory == null || _selectedState == null || _harvestDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // TODO: Actually create trophy with Supabase
    await Future.delayed(const Duration(seconds: 1));

    setState(() => _isLoading = false);

    if (mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trophy posted successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Trophy'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // Photo upload section
          _PhotoUploadSection(),
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
          
          // State selection
          PremiumDropdown<String>(
            label: 'State *',
            items: _states,
            value: _selectedState,
            onChanged: (value) {
              setState(() {
                _selectedState = value;
                _selectedCounty = null;
              });
            },
            itemLabel: (item) => item,
            hint: 'Select state',
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // County selection
          PremiumDropdown<String>(
            label: 'County *',
            items: _selectedState != null
                ? ['${_selectedState!} County 1', '${_selectedState!} County 2']
                : [],
            value: _selectedCounty,
            onChanged: (value) {
              setState(() => _selectedCounty = value);
            },
            itemLabel: (item) => item,
            hint: _selectedState == null ? 'Select state first' : 'Select county',
            enabled: _selectedState != null,
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Harvest date
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Harvest Date *',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppColors.charcoalLight),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        _harvestDate != null
                            ? '${_harvestDate!.month}/${_harvestDate!.day}/${_harvestDate!.year}'
                            : 'Select date',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: _harvestDate == null
                              ? AppColors.charcoalLight
                              : AppColors.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.boneLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Species Stats',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _selectedCategory != null
                      ? 'Add ${_selectedCategory!}-specific stats like score, weight, etc.'
                      : 'Select a category to see specific stat fields.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.charcoalLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          
          // Submit button
          PremiumButton(
            label: 'Post Trophy',
            onPressed: _submit,
            isLoading: _isLoading,
            isExpanded: true,
          ),
        ],
      ),
    );
  }
}

class _PhotoUploadSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.boneLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.borderLight,
          style: BorderStyle.solid,
        ),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Image picker
        },
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Icon(
                  Icons.add_a_photo,
                  size: 32,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Add Photos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tap to upload trophy photos',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
