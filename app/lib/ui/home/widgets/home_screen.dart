import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../view_models/home_view_model.dart';

/// Opens [url] outside the app; returns whether it could.
typedef UrlOpener = Future<bool> Function(Uri url);

Future<bool> _openExternally(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

final _releasesUrl = Uri.parse('https://github.com/angelobez/plantai/releases');

/// Shows whether the app can talk to the API and its database.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.viewModel,
    this.openUrl = _openExternally,
  });

  final HomeViewModel viewModel;
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PlantAí')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListenableBuilder(
              listenable: viewModel,
              builder: (context, _) => switch (viewModel.state) {
                HomeLoading() => const _Loading(),
                HomeConnected(:final apiVersion, :final postgisVersion) =>
                  _Connected(
                    apiVersion: apiVersion,
                    postgisVersion: postgisVersion,
                  ),
                HomeFailed(failure: HomeFailure.updateRequired) =>
                  _UpdateRequired(openUrl: openUrl),
                HomeFailed(:final failure) => _Failed(
                  message: _messageFor(failure),
                  onRetry: viewModel.load,
                ),
              },
            ),
          ),
        ),
      ),
    );
  }

  static String _messageFor(HomeFailure failure) => switch (failure) {
    HomeFailure.noConnection =>
      'Não foi possível falar com a API. Confira se ela está rodando e se '
          'o celular está conectado ao notebook.',
    HomeFailure.databaseDown =>
      'A API respondeu, mas o banco de dados está fora do ar.',
    HomeFailure.updateRequired ||
    HomeFailure.unknown => 'Algo deu errado ao falar com a API.',
  };
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Conectando à API…'),
      ],
    );
  }
}

class _Connected extends StatelessWidget {
  const _Connected({required this.apiVersion, required this.postgisVersion});

  final String apiVersion;
  final String postgisVersion;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline, size: 48),
        const SizedBox(height: 16),
        Text('Conectado à API', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('Versão da API: $apiVersion'),
        Text('Versão do PostGIS: $postgisVersion'),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, size: 48),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Tentar de novo')),
      ],
    );
  }
}

class _UpdateRequired extends StatelessWidget {
  const _UpdateRequired({required this.openUrl});

  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.system_update_outlined, size: 48),
        const SizedBox(height: 16),
        Text(
          'Atualize o PlantAí',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Esta versão do app não é mais aceita. Baixe a nova versão em:',
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: () => openUrl(_releasesUrl),
          child: Text(_releasesUrl.toString()),
        ),
      ],
    );
  }
}
