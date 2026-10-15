import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../widgets/app_ui.dart';
import 'legal_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/icon/attendx_icon.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'AttendX',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  _versionLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                const AppSurface(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FeatureChip(
                        icon: Icons.offline_bolt_outlined,
                        text: 'Works fully offline',
                      ),
                      _FeatureChip(
                        icon: Icons.view_agenda_outlined,
                        text: 'Name cards or number grid',
                      ),
                      _FeatureChip(
                        icon: Icons.calendar_month_outlined,
                        text: 'Today and backdated attendance',
                      ),
                      _FeatureChip(
                        icon: Icons.person_add_alt_1_outlined,
                        text: 'Safe roster updates',
                      ),
                      _FeatureChip(
                        icon: Icons.file_download_outlined,
                        text: 'CSV export by date range',
                      ),
                      _FeatureChip(
                        icon: Icons.cloud_outlined,
                        text: 'Optional Google Drive backup',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppSurface(
                  child: ListTile(
                    minTileHeight: 56,
                    leading: const Icon(
                      Icons.privacy_tip_outlined,
                      size: 22,
                      color: AppColors.primary,
                    ),
                    title: const Text('Privacy & legal'),
                    subtitle: const Text('Policies and licenses'),
                    trailing: const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.textDisabled,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LegalScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Open source \u00B7 No ads \u00B7 No tracking',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '\u00A9 2026 AttendX contributors',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String get _versionLabel {
    const name = String.fromEnvironment('FLUTTER_BUILD_NAME');
    const number = String.fromEnvironment('FLUTTER_BUILD_NUMBER');
    if (name.isEmpty) return 'Development build';
    return number.isEmpty ? name : '$name+$number';
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
