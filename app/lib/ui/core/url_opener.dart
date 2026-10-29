import 'package:url_launcher/url_launcher.dart';

/// Opens [url] outside the app; returns whether it could. Screens take one so
/// widget tests can see the URL without launching a browser.
typedef UrlOpener = Future<bool> Function(Uri url);

Future<bool> openExternally(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);
