import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';
import '../../core/url_opener.dart';
import '../../core/widgets/plantai_logo.dart';

/// Where new versions of the app are published.
final releasesUrl = Uri.parse('https://github.com/angelobez/plantai/releases');

/// "Atualize o PlantAí": the API refused this app version (`426
/// APP_UPDATE_REQUIRED`). There is no way back; only a new build helps.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, required this.openUrl});

  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PlantaiLogo(),
                  const SizedBox(height: 32),
                  const Icon(
                    Icons.system_update_outlined,
                    size: 48,
                    color: AppColors.forest,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Atualize o PlantAí',
                    style: textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Esta versão do app não é mais aceita. Baixe a nova versão '
                    'em:',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  TextButton(
                    onPressed: () => openUrl(releasesUrl),
                    child: Text(
                      releasesUrl.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
