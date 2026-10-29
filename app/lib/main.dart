import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'data/repositories/health/health_repository.dart';
import 'data/repositories/health/health_repository_remote.dart';
import 'data/services/api/api_client.dart';
import 'routing/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final packageInfo = await PackageInfo.fromPlatform();
  final apiClient = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    appVersion: packageInfo.version,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<HealthRepository>(
          create: (_) => HealthRepositoryRemote(apiClient: apiClient),
        ),
      ],
      child: const PlantaiApp(),
    ),
  );
}

class PlantaiApp extends StatefulWidget {
  const PlantaiApp({super.key});

  @override
  State<PlantaiApp> createState() => _PlantaiAppState();
}

class _PlantaiAppState extends State<PlantaiApp> {
  final _router = router();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PlantAí',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      routerConfig: _router,
    );
  }
}
