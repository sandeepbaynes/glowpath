import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

const publicSite = String.fromEnvironment(
  'PUBLIC_SITE_URL',
  defaultValue: 'https://glowpath-38p.pages.dev/',
);

Uri publicPageUri(String page, {Uri? browserBase}) {
  final base = browserBase ?? (kIsWeb ? Uri.base : Uri.parse(publicSite));
  return base.resolve(page);
}

Future<bool> openPublicPage(String page) => launchUrl(
  publicPageUri(page),
  mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
  webOnlyWindowName: '_blank',
);
