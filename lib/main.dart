import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/hive_constants.dart';
import 'core/app_theme.dart';
import 'core/snapshot_storage.dart';
import 'data/models/class_entry.dart';
import 'data/models/snapshot_entry.dart';
import 'screens/attendance_grid_screen.dart';
import 'screens/create_class_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/manage_class_screen.dart';
import 'screens/roster_ingestion_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: _StartupGate()));
}

Future<void> _openLocalStorage() async {
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ClassEntryAdapter());
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(SnapshotEntryAdapter());
  }

  await Future.wait<dynamic>([
    Hive.openBox<ClassEntry>(HiveConstants.classBox),
    Hive.openBox<dynamic>(HiveConstants.settingsBox),
  ]);

  // Attendance history can be large. Open it after the dashboard's first
  // frame so it does not delay the initial UI.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_openHistory());
  });
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late Future<void> _storage = _openLocalStorage();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _storage,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return const AttendXApp();
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: snapshot.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Could not open local data. Free some device storage and retry. Avoid uninstalling unless you have a backup.',
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () =>
                                setState(() => _storage = _openLocalStorage()),
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(
                        semanticsLabel: 'Opening AttendX',
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _openHistory() async {
  try {
    await openSnapshotBox();
  } catch (error) {
    debugPrint('AttendX attendance history could not open: $error');
  }
}

class AttendXApp extends StatelessWidget {
  const AttendXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AttendX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute<void>(
              builder: (_) => const DashboardScreen(),
              settings: settings,
            );
          case '/grid':
            final history = openSnapshotBox();
            return MaterialPageRoute<void>(
              builder: (_) => FutureBuilder<Box<SnapshotEntry>>(
                future: history,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Scaffold(
                      appBar: AppBar(title: const Text('Attendance')),
                      body: const Center(
                        child: Text('Could not load attendance history'),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return Scaffold(
                      appBar: AppBar(title: const Text('Attendance')),
                      body: const Center(child: CircularProgressIndicator()),
                    );
                  }
                  return AttendanceGridScreen(
                    classEntry: settings.arguments! as ClassEntry,
                  );
                },
              ),
              settings: settings,
            );
          case '/create':
            return MaterialPageRoute<void>(
              builder: (_) => const CreateClassScreen(),
              settings: settings,
            );
          case '/manage':
            return MaterialPageRoute<void>(
              builder: (_) => ManageClassScreen(
                classEntry: settings.arguments! as ClassEntry,
              ),
              settings: settings,
            );
          case '/roster':
            return MaterialPageRoute<ClassEntry>(
              builder: (_) => RosterIngestionScreen(
                classEntry: settings.arguments! as ClassEntry,
              ),
              settings: settings,
            );
          default:
            return MaterialPageRoute<void>(
              builder: (_) => const DashboardScreen(),
              settings: settings,
            );
        }
      },
    );
  }
}
