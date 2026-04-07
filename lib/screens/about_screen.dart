import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Widget _featureRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/icon/attendx_icon.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'AttendX',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'v1.0.0',
                  style: TextStyle(
                    fontSize: 14,
                    color: muted,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(),
                ),
                _featureRow(context, Icons.offline_bolt, 'Works fully offline'),
                _featureRow(context, Icons.grid_view, '6×10 attendance grid'),
                _featureRow(
                    context, Icons.file_download, 'CSV export via share'),
                _featureRow(context, Icons.history, 'Full attendance history'),
                _featureRow(
                  context,
                  Icons.no_encryption,
                  'No login. No cloud. No tracking.',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(),
                ),
                Text(
                  'Made by',
                  style: TextStyle(
                    fontSize: 13,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'LOGIC | STUDIO',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3.0,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'logicstudio.co.in',
                  style: TextStyle(
                    fontSize: 13,
                    color: muted,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(),
                ),
                Text(
                  'Your data never leaves your device.',
                  style: TextStyle(
                    fontSize: 12,
                    color: muted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No analytics. No ads. No accounts.',
                  style: TextStyle(
                    fontSize: 12,
                    color: muted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
