import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'data/services/api/api_client.dart';
import 'data/services/api/update_required.dart';
import 'routing/router.dart';
import 'ui/core/themes/theme.dart';
import 'ui/core/url_opener.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final packageInfo = await PackageInfo.fromPlatform();
  final updateRequired = UpdateRequired();
  final apiClient = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    appVersion: packageInfo.version,
    updateRequired: updateRequired,
  );

  runApp(
    // Repositories go here, built on the shared ApiClient.
    MultiProvider(
      providers: [Provider<ApiClient>.value(value: apiClient)],
      child: PlantaiApp(updateRequired: updateRequired),
    ),
  );
}

class PlantaiApp extends StatefulWidget {
  const PlantaiApp({
    super.key,
    required this.updateRequired,
    this.openUrl = openExternally,
  });

  final UpdateRequired updateRequired;
  final UrlOpener openUrl;

  @override
  State<PlantaiApp> createState() => _PlantaiAppState();
}

class _PlantaiAppState extends State<PlantaiApp> {
  late final _router = router(
    updateRequired: widget.updateRequired,
    openUrl: widget.openUrl,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PlantAí',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
