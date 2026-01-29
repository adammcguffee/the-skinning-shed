import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../services/clubs_service.dart';

/// Club Settings Screen - Admin only
class ClubSettingsScreen extends ConsumerStatefulWidget {
  const ClubSettingsScreen({super.key, required this.clubId});
  
  final String clubId;

  @override
  ConsumerState<ClubSettingsScreen> createState() => _ClubSettingsScreenState();
}

class _ClubSettingsScreenState extends ConsumerState<ClubSettingsScreen> {
  bool _isLoading = false;
  bool _isSaving = false;
  
  // Form state
  bool _isDiscoverable = false;
  bool _requireApproval = true;
  int _signInTtlHours = 6;
  bool _allowMembersCreateStands = false;
  
  bool _hasChanges = false;
  Club? _club;
  
  @override
  void initState() {
    super.initState();
    _loadClub();
  }
  
  Future<void> _loadClub() async {
    setState(() => _isLoading = true);
    
    final service = ref.read(clubsServiceProvider);
    final club = await service.getClub(widget.clubId);
    
    if (club != null && mounted) {
      setState(() {
        _club = club;
        _isDiscoverable = club.isDiscoverable;
        _requireApproval = club.requireApproval;
        _signInTtlHours = club.settings.signInTtlHours;
        _allowMembersCreateStands = club.settings.allowMembersCreateStands;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }
  
  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }
  
  Future<void> _save() async {
    if (_club == null) return;
    
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();
    
    final service = ref.read(clubsServiceProvider);
    final success = await service.updateClubSettings(
      widget.clubId,
      isDiscoverable: _isDiscoverable,
      requireApproval: _requireApproval,
      settings: ClubSettings(
        signInTtlHours: _signInTtlHours,
        allowMembersCreateStands: _allowMembersCreateStands,
      ),
    );
    
    if (mounted) {
      setState(() => _isSaving = false);
      
      if (success) {
        ref.invalidate(clubProvider(widget.clubId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() => _hasChanges = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save settings'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textPrimary,
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/clubs/${widget.clubId}');
            }
          },
        ),
        title: const Text(
          'Club Settings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_hasChanges)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _club == null
              ? const Center(child: Text('Club not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Visibility Section
                      _SectionHeader(title: 'Visibility'),
                      _SettingsCard(
                        children: [
                          _SettingsSwitch(
                            title: 'Discoverable',
                            subtitle: 'Allow users to find this club in search',
                            value: _isDiscoverable,
                            onChanged: (v) {
                              setState(() => _isDiscoverable = v);
                              _markChanged();
                            },
                          ),
                          if (_isDiscoverable) ...[
                            const Divider(height: 1),
                            _SettingsSwitch(
                              title: 'Require Approval',
                              subtitle: 'Review requests before users can join',
                              value: _requireApproval,
                              onChanged: (v) {
                                setState(() => _requireApproval = v);
                                _markChanged();
                              },
                            ),
                          ],
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Stands Section
                      _SectionHeader(title: 'Stands'),
                      _SettingsCard(
                        children: [
                          _SettingsDropdown(
                            title: 'Default Sign-in Duration',
                            subtitle: 'How long stand holds last by default',
                            value: _signInTtlHours,
                            options: const [1, 2, 4, 6, 8, 10, 12],
                            labelBuilder: (v) => '$v hours',
                            onChanged: (v) {
                              setState(() => _signInTtlHours = v);
                              _markChanged();
                            },
                          ),
                          const Divider(height: 1),
                          _SettingsSwitch(
                            title: 'Members Can Create Stands',
                            subtitle: 'Allow non-admins to add new stands',
                            value: _allowMembersCreateStands,
                            onChanged: (v) {
                              setState(() => _allowMembersCreateStands = v);
                              _markChanged();
                            },
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Danger Zone
                      _SectionHeader(title: 'Danger Zone', isDestructive: true),
                      _SettingsCard(
                        isDestructive: true,
                        children: [
                          ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                            ),
                            title: const Text(
                              'Delete Club',
                              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                              'Permanently delete this club and all data',
                              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                            ),
                            onTap: () => _showDeleteConfirmation(),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
  
  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Delete Club?'),
        content: Text(
          'This will permanently delete "${_club?.name}" and all its data. This action cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      HapticFeedback.heavyImpact();
      final service = ref.read(clubsServiceProvider);
      final success = await service.deleteClub(widget.clubId);
      
      if (success && mounted) {
        context.go('/clubs');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Club deleted')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete club'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.isDestructive = false});
  
  final String title;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: isDestructive ? AppColors.error : AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children, this.isDestructive = false});
  
  final List<Widget> children;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDestructive 
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.border,
          width: 0.5,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 12,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _SettingsDropdown extends StatelessWidget {
  const _SettingsDropdown({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.onChanged,
  });
  
  final String title;
  final String subtitle;
  final int value;
  final List<int> options;
  final String Function(int) labelBuilder;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 12,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: DropdownButton<int>(
          value: value,
          isDense: true,
          underline: const SizedBox.shrink(),
          dropdownColor: AppColors.surfaceElevated,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          items: options.map((o) => DropdownMenuItem(
            value: o,
            child: Text(labelBuilder(o)),
          )).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
