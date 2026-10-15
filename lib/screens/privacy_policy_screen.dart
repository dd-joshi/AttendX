import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The same policy file is bundled in the app and published with the project.
class PrivacyPolicyScreen extends StatelessWidget {
  PrivacyPolicyScreen({super.key});

  final Future<String> _policy = rootBundle.loadString('PRIVACY.md');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: FutureBuilder<String>(
        future: _policy,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Could not open the privacy policy.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final paragraph
                    in snapshot.data!
                        .replaceAll('\r\n', '\n')
                        .trim()
                        .split('\n\n')
                        .skip(1))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      paragraph.startsWith('## ')
                          ? paragraph.substring(3)
                          : paragraph.replaceAll('\n', ' '),
                      style: paragraph.startsWith('## ')
                          ? Theme.of(context).textTheme.titleMedium
                          : Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
