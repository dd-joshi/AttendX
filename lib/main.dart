import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/hive_constants.dart';
import 'data/models/class_entry.dart';
import 'data/models/snapshot_entry.dart';
import 'screens/attendance_grid_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/roster_ingestion_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(ClassEntryAdapter());
  Hive.registerAdapter(SnapshotEntryAdapter());

  await Hive.openBox<ClassEntry>(HiveConstants.classBox);
  await Hive.openBox<SnapshotEntry>(HiveConstants.snapshotBox);

  runApp(const ProviderScope(child: AttendXApp()));
}

class AttendXApp extends StatelessWidget {
  const AttendXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AttendX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute<void>(
              builder: (_) => const DashboardScreen(),
              settings: settings,
            );
          case '/grid':
            return MaterialPageRoute<void>(
              builder: (_) => AttendanceGridScreen(
                classEntry: settings.arguments! as ClassEntry,
              ),
              settings: settings,
            );
          case '/ingest':
            return MaterialPageRoute<void>(
              builder: (_) => const RosterIngestionScreen(),
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
