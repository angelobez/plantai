import 'package:flutter/material.dart';

import '../../../data/services/api/models/reference_photo.dart';
import '../themes/colors.dart';
import '../url_opener.dart';

/// The discreet credit under a reference photo: "Foto de referência: autor ·
/// licença · site", where the site is a link to the photo's page.
class ReferencePhotoCredit extends StatelessWidget {
  const ReferencePhotoCredit({
    super.key,
    required this.photo,
    required this.openUrl,
  });

  final ReferencePhoto photo;
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    final source = Uri.tryParse(photo.sourceUrl);
    const style = TextStyle(fontSize: 12, color: AppColors.inkMuted);
    final text = Text.rich(
      TextSpan(
        text: 'Foto de referência: ${photo.author} · ${photo.license}',
        children: [
          if (source != null && source.host.isNotEmpty) ...[
            const TextSpan(text: ' · '),
            TextSpan(
              text: source.host,
              style: const TextStyle(
                color: AppColors.forest,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.forest,
              ),
            ),
          ],
        ],
      ),
      style: style,
    );
    if (source == null) return text;
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () => openUrl(source),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: text,
        ),
      ),
    );
  }
}
