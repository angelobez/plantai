import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';
import '../../core/url_opener.dart';
import '../../core/widgets/plantai_logo.dart';

/// A service or work the app relies on, with the link to where it comes from.
typedef _Credit = ({String title, String text, String url});

const _helpers = <_Credit>[
  (
    title: 'Pl@ntNet',
    text: 'Identificação das plantas pela foto',
    url: 'https://plantnet.org/',
  ),
  (
    title: 'Claude, da Anthropic',
    text:
        'As dicas de cuidado de cada espécie são geradas por IA e podem ter '
        'erros',
    url: 'https://www.anthropic.com/claude',
  ),
  (
    title: 'Flora e Funga do Brasil',
    text: 'Nomes científicos e populares das espécies do Brasil',
    url: 'https://floradobrasil.jbrj.gov.br/',
  ),
  (
    title: 'GBIF',
    text: 'Nomes científicos e o elo entre as espécies e o Pl@ntNet',
    url: 'https://www.gbif.org/',
  ),
];

const _photos = <_Credit>[
  (
    title: 'Wikimedia Commons',
    text:
        'Fotos de referência das espécies. O autor e a licença de cada uma '
        'ficam embaixo da foto',
    url: 'https://commons.wikimedia.org/',
  ),
];

const _font = <_Credit>[
  (
    title: 'Fonte Manrope',
    text: '© 2018 The Manrope Project Authors · SIL Open Font License 1.1',
    url: 'https://github.com/googlefonts/manrope',
  ),
];

/// "Sobre e créditos", opened from Perfil, as in the Claude Design screen
/// (`M-sobre`): who helps the app, where the reference photos come from and
/// the font license. Each credit opens its origin outside the app.
///
/// The design lists a few reference photos with their credits; that list
/// needs the Catálogo, so here Wikimedia Commons is credited as a whole and
/// each photo carries its own credit where it is shown.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, required this.openUrl});

  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: IconButton(
            tooltip: 'Voltar',
            onPressed: () => Navigator.of(context).maybePop(),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.mist,
              foregroundColor: AppColors.ink,
              fixedSize: const Size(44, 44),
            ),
            icon: const Icon(Icons.chevron_left, size: 24),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Sobre e créditos',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: PlantaiLogo(fontSize: 22, showLeaf: false),
            ),
            const SizedBox(height: 8),
            const Text(
              'Um projeto de portfólio para identificar plantas, cuidar delas '
              'e doar mudas entre vizinhos.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF3A453D),
              ),
            ),
            _Section(title: 'QUEM AJUDA', credits: _helpers, openUrl: openUrl),
            _Section(
              title: 'FOTOS DE REFERÊNCIA',
              credits: _photos,
              openUrl: openUrl,
            ),
            _Section(title: 'FONTE', credits: _font, openUrl: openUrl),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.credits,
    required this.openUrl,
  });

  final String title;
  final List<_Credit> credits;
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(height: 4),
          for (final credit in credits)
            _CreditRow(
              credit: credit,
              onTap: () => openUrl(Uri.parse(credit.url)),
            ),
        ],
      ),
    );
  }
}

/// The bold title over the muted text, with the "opens outside" icon.
class _CreditRow extends StatelessWidget {
  const _CreditRow({required this.credit, required this.onTap});

  final _Credit credit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      credit.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      credit.text,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.open_in_new,
                size: 18,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
