import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/regulations_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// 🔗 OFFICIAL LINKS ADMIN - 2026 PREMIUM
/// 
/// Clean, minimal admin for official links:
/// - Overview of link coverage
/// - List of all state official URLs
class RegulationsAdminScreen extends ConsumerStatefulWidget {
  const RegulationsAdminScreen({super.key});

  @override
  ConsumerState<RegulationsAdminScreen> createState() => _RegulationsAdminScreenState();
}

class _RegulationsAdminScreenState extends ConsumerState<RegulationsAdminScreen> {
  bool _isLoading = true;
  Map<String, String?> _officialUrls = {};
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final service = ref.read(regulationsServiceProvider);
      final urls = await service.fetchAllOfficialRootUrls();
      
      if (mounted) {
        setState(() {
          _officialUrls = urls;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Official Links Admin',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                Text(
                  'Manage state wildlife portal links',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadData,
            icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }
  
  Widget _buildContent() {
    final statesWithUrls = _officialUrls.entries
        .where((e) => e.value != null && e.value!.isNotEmpty)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    final statesWithoutUrls = _officialUrls.entries
        .where((e) => e.value == null || e.value!.isEmpty)
        .map((e) => e.key)
        .toList()
      ..sort();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        0,
        AppSpacing.screenPadding,
        AppSpacing.screenPadding + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats overview
          _buildStatsSection(statesWithUrls.length),
          const SizedBox(height: AppSpacing.xl + 8),
          
          // Missing links section
          if (statesWithoutUrls.isNotEmpty) ...[
            _buildMissingSection(statesWithoutUrls),
            const SizedBox(height: AppSpacing.xl + 8),
          ],
          
          // All links list
          _buildLinksListSection(statesWithUrls),
        ],
      ),
    );
  }
  
  Widget _buildStatsSection(int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.insights_rounded, size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            const Text(
              'Link Coverage',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Expanded(
                child: _BigStatTile(
                  label: 'States with Links',
                  value: '$count / 50',
                  icon: Icons.link_rounded,
                  color: count >= 50 ? AppColors.success : AppColors.info,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _BigStatTile(
                  label: 'Coverage',
                  value: '${(count / 50 * 100).round()}%',
                  icon: Icons.verified_rounded,
                  color: count >= 50 ? AppColors.success : AppColors.info,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildMissingSection(List<String> missingStates) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
            ),
            const SizedBox(width: 12),
            Text(
              'Missing Links (${missingStates.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: missingStates.map((code) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildLinksListSection(List<MapEntry<String, String?>> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.list_rounded, size: 18, color: AppColors.success),
            ),
            const SizedBox(width: 12),
            Text(
              'All Official Links (${links.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: links.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderSubtle),
            itemBuilder: (context, index) {
              final entry = links[index];
              final stateCode = entry.key;
              final url = entry.value ?? '';
              final domain = Uri.tryParse(url)?.host ?? url;
              
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      stateCode,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  domain,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.textTertiary),
                  onPressed: () => _openUrl(url),
                  tooltip: 'Open link',
                ),
                onTap: () => _openUrl(url),
              );
            },
          ),
        ),
      ],
    );
  }
}

// === WIDGETS ===

class _BigStatTile extends StatelessWidget {
  const _BigStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
