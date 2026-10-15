import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../widgets/app_ui.dart';
import 'privacy_policy_screen.dart';

/// Privacy policy, open-source licenses, source link, and legal notes.
///
/// Tucked behind a single entry on the About screen so the main page stays
/// product-focused instead of reading like a terms-and-conditions listing.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  static const _githubUrl = 'https://github.com/dd-joshi/AttendX';

  Future<void> _copyGitHubLink(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _githubUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('GitHub link copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & legal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSurface(
                  child: Column(
                    children: [
                      ListTile(
                        minTileHeight: 52,
                        leading: const Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        title: const Text('Privacy policy'),
                        subtitle: const Text(
                          'Your attendance stays under your control',
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: AppColors.textDisabled,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PrivacyPolicyScreen(),
                          ),
                        ),
                      ),
                      const Divider(indent: 16, endIndent: 16),
                      ListTile(
                        minTileHeight: 52,
                        leading: const Icon(
                          Icons.balance_outlined,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        title: const Text('Open-source licenses'),
                        trailing: const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: AppColors.textDisabled,
                        ),
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName: 'AttendX',
                        ),
                      ),
                      const Divider(indent: 16, endIndent: 16),
                      ListTile(
                        minTileHeight: 52,
                        leading: const Icon(
                          Icons.code_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        title: const Text('Source on GitHub'),
                        subtitle: const Text('github.com/dd-joshi/AttendX'),
                        trailing: const Icon(
                          Icons.copy_outlined,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        onTap: () => _copyGitHubLink(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No login, ads, or tracking. Backups and exports happen '
                  'only when you choose.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
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
}