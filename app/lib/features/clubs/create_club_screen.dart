import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../data/us_counties.dart';
import '../../data/us_states.dart';
import '../../navigation/app_routes.dart';
import '../../services/clubs_service.dart';

/// Screen for creating a new hunting club
class CreateClubScreen extends ConsumerStatefulWidget {
  const CreateClubScreen({super.key});

  @override
  ConsumerState<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends ConsumerState<CreateClubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isDiscoverable = false;
  bool _requireApproval = true;
  int _signInTtlHours = 6;
  bool _isSubmitting = false;
  String? _selectedState;
  String? _selectedCounty;
  
  static const _ttlOptions = [2, 4, 6, 8, 10, 12];
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmitting = true);
    
    final service = ref.read(clubsServiceProvider);
    final clubId = await service.createClub(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim(),
      isDiscoverable: _isDiscoverable,
      requireApproval: _requireApproval,
      settings: ClubSettings(
        signInTtlHours: _signInTtlHours,
      ),
      stateCode: _selectedState,
      county: _selectedCounty,
    );
    
    if (!mounted) return;
    
    if (clubId != null) {
      // Refresh clubs list
      ref.invalidate(myClubsProvider);
      
      // Navigate to the new club
      context.go(AppRoutes.clubDetail(clubId));
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create club. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Create Hunting Club'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Club Name
            _buildSectionTitle('Club Name'),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _inputDecoration(
                label: 'Club Name',
                hint: 'e.g., Big Buck Hunting Club',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter a club name';
                }
                if (v.trim().length < 3) {
                  return 'Name must be at least 3 characters';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            // Description
            _buildSectionTitle('Description'),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _inputDecoration(
                label: 'Description (optional)',
                hint: 'Tell members what this club is about',
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // Location
            _buildSectionTitle('Location'),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Help members find your club by adding a location',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                // State dropdown
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedState,
                        hint: Text(
                          'Select State',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                        dropdownColor: AppColors.surfaceElevated,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('No State'),
                          ),
                          ...USStates.all.map((state) => DropdownMenuItem(
                            value: state.code,
                            child: Text(state.name),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedState = value;
                            _selectedCounty = null; // Reset county when state changes
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // County dropdown
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _selectedState == null 
                          ? AppColors.surface 
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCounty,
                        hint: Text(
                          _selectedState == null ? 'Select state first' : 'Select County',
                          style: TextStyle(
                            color: _selectedState == null 
                                ? AppColors.textTertiary.withValues(alpha: 0.5)
                                : AppColors.textTertiary,
                          ),
                        ),
                        dropdownColor: AppColors.surfaceElevated,
                        isExpanded: true,
                        icon: Icon(
                          Icons.arrow_drop_down_rounded, 
                          color: _selectedState == null 
                              ? AppColors.textTertiary.withValues(alpha: 0.3)
                              : AppColors.textSecondary,
                        ),
                        items: _selectedState == null
                            ? []
                            : [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('No County'),
                                ),
                                ...USCounties.forState(_selectedState!).map((county) => 
                                  DropdownMenuItem(
                                    value: county,
                                    child: Text(county),
                                  ),
                                ),
                              ],
                        onChanged: _selectedState == null
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedCounty = value;
                                });
                              },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // Visibility Settings
            _buildSectionTitle('Visibility'),
            const SizedBox(height: AppSpacing.sm),
            _buildSettingsCard(
              children: [
                SwitchListTile(
                  value: _isDiscoverable,
                  onChanged: (v) => setState(() => _isDiscoverable = v),
                  title: const Text(
                    'Discoverable',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    'Allow others to find and request to join',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
                if (_isDiscoverable) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _requireApproval,
                    onChanged: (v) => setState(() => _requireApproval = v),
                    title: const Text(
                      'Require Approval',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      'Admins must approve join requests',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // Stand Settings
            _buildSectionTitle('Stand Sign-In Settings'),
            const SizedBox(height: AppSpacing.sm),
            _buildSettingsCard(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Auto-Expire Sign-Ins',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    'Sign-ins automatically expire after this duration',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: DropdownButton<int>(
                    value: _signInTtlHours,
                    dropdownColor: AppColors.surfaceElevated,
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: _ttlOptions.map((hours) {
                      return DropdownMenuItem(
                        value: hours,
                        child: Text('${hours}h'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _signInTtlHours = v);
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // Info card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'You will be the owner and can invite members after creating the club.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create Club',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
  
  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: children,
      ),
    );
  }
  
  InputDecoration _inputDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: TextStyle(color: AppColors.textTertiary),
      filled: true,
      fillColor: AppColors.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }
}
