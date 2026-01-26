import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_counties.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/services/profile_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🎨 EDIT PROFILE SCREEN - 2026 PREMIUM
///
/// Full profile editing with:
/// - Avatar upload/change/remove
/// - Display name + bio
/// - Home state/county selection
/// - Favorite species multi-select
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _imagePicker = ImagePicker();
  
  USState? _selectedState;
  String? _selectedCounty;
  List<String> _selectedSpecies = [];
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _avatarPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final profileService = ref.read(profileServiceProvider);
      final profile = await profileService.getCurrentProfile();
      
      if (profile != null && mounted) {
        setState(() {
          _displayNameController.text = profile.displayName ?? '';
          _bioController.text = profile.bio ?? '';
          _avatarPath = profile.avatarPath;
          _selectedSpecies = profile.favoriteSpecies ?? [];
          
          if (profile.defaultState != null) {
            _selectedState = USStates.all.firstWhere(
              (s) => s.code == profile.defaultState || s.name == profile.defaultState,
              orElse: () => USStates.all.first,
            );
          }
          _selectedCounty = profile.defaultCounty;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (photo != null) {
        setState(() => _isUploadingAvatar = true);
        
        final bytes = await photo.readAsBytes();
        final profileService = ref.read(profileServiceProvider);
        final path = await profileService.uploadAvatar(bytes, photo.name);
        
        if (mounted) {
          if (path != null) {
            setState(() => _avatarPath = path);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Avatar updated!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to upload avatar')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _removeAvatar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Remove Avatar?'),
        content: const Text('Your profile photo will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() => _isUploadingAvatar = true);
      
      try {
        final profileService = ref.read(profileServiceProvider);
        final success = await profileService.removeAvatar();
        
        if (mounted) {
          if (success) {
            setState(() => _avatarPath = null);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Avatar removed')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUploadingAvatar = false);
        }
      }
    }
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final profileService = ref.read(profileServiceProvider);
      final success = await profileService.updateProfile(
        displayName: _displayNameController.text.trim().isNotEmpty 
            ? _displayNameController.text.trim() 
            : null,
        bio: _bioController.text.trim().isNotEmpty 
            ? _bioController.text.trim() 
            : null,
        defaultState: _selectedState?.code,
        defaultCounty: _selectedCounty,
        favoriteSpecies: _selectedSpecies.isNotEmpty ? _selectedSpecies : null,
      );
      
      if (mounted) {
        if (success) {
          // Invalidate profile cache
          ref.invalidate(currentProfileProvider);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile saved!')),
          );
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save profile')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            // Header
            PageHeader(
              title: 'Edit Profile',
              subtitle: 'Customize your Trophy Wall',
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
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: AppErrorState(
                            message: _error!,
                            onRetry: _loadProfile,
                          ),
                        )
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              // Avatar section
              _buildAvatarSection(),
              const SizedBox(height: AppSpacing.xxl),
              
              // Display name
              _SectionHeader(title: 'Display Name'),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _displayNameController,
                label: 'Display Name',
                hint: 'How you want to appear',
                prefixIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: AppSpacing.xl),
              
              // Bio
              _SectionHeader(title: 'Bio'),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _bioController,
                label: 'Bio',
                hint: 'Tell others about yourself...',
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.xl),
              
              // Home location
              _SectionHeader(title: 'Home Location'),
              const SizedBox(height: AppSpacing.sm),
              AppDropdownField<USState>(
                label: 'State',
                value: _selectedState,
                items: USStates.all
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (state) {
                  setState(() {
                    _selectedState = state;
                    _selectedCounty = null;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.md),
              if (_selectedState != null)
                AppDropdownField<String>(
                  label: 'County',
                  value: _selectedCounty,
                  items: USCounties.forState(_selectedState!.code)
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (county) {
                    setState(() => _selectedCounty = county);
                  },
                ),
              const SizedBox(height: AppSpacing.xl),
              
              // Favorite species
              _SectionHeader(
                title: 'Favorite Species',
                subtitle: 'Select all that apply',
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildSpeciesSelector(),
              
              const SizedBox(height: AppSpacing.xxxl),
              
              // Save button (mobile)
              AppButtonPrimary(
                label: 'Save Profile',
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
    );
  }

  Widget _buildAvatarSection() {
    final profileService = ref.read(profileServiceProvider);
    final avatarUrl = profileService.getAvatarUrl(_avatarPath);
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_circle_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Profile Photo',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Avatar preview
          GestureDetector(
            onTap: _isUploadingAvatar ? null : _pickAvatar,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.accentGradient,
                      boxShadow: AppColors.shadowAccent,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _isUploadingAvatar
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : avatarUrl != null
                              ? Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  width: 114,
                                  height: 114,
                                  errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(),
                                )
                              : _buildAvatarPlaceholder(),
                    ),
                  ),
                  
                  // Edit overlay
                  if (!_isUploadingAvatar)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                          boxShadow: AppColors.shadowCard,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 18,
                          color: AppColors.textInverse,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _isUploadingAvatar ? null : _pickAvatar,
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: Text(_avatarPath != null ? 'Change Photo' : 'Upload Photo'),
              ),
              if (_avatarPath != null) ...[
                const SizedBox(width: AppSpacing.md),
                TextButton.icon(
                  onPressed: _isUploadingAvatar ? null : _removeAvatar,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                ),
              ],
            ],
          ),
          
          // Helper text
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tap photo or click buttons to change',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      color: AppColors.surfaceHover,
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          size: 48,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSpeciesSelector() {
    final species = [
      ('deer', 'Whitetail Deer', Icons.pets_rounded, AppColors.categoryDeer),
      ('turkey', 'Turkey', Icons.flutter_dash_rounded, AppColors.categoryTurkey),
      ('bass', 'Largemouth Bass', Icons.water_rounded, AppColors.categoryBass),
      ('other_game', 'Other Game', Icons.nature_people_rounded, AppColors.categoryOtherGame),
      ('other_fishing', 'Other Fishing', Icons.phishing_rounded, AppColors.categoryOtherFishing),
    ];
    
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: species.map((s) {
        final isSelected = _selectedSpecies.contains(s.$1);
        return AppChip(
          label: s.$2,
          color: s.$4,
          isSelected: isSelected,
          onTap: () => _toggleSpecies(s.$1),
        );
      }).toList(),
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
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
