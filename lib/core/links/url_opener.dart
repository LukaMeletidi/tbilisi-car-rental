import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link (tel:, mailto: or https:) outside the app. true when it was
/// handed to an app or a browser tab; false when nothing could open it.
///
/// On the web a tel: or mailto: link usually reports true even when no
/// program takes it, so screens also offer to copy the text.
typedef UrlOpener = Future<bool> Function(Uri uri);

/// The only place of the app that uses url_launcher; tests replace it.
final urlOpenerProvider = Provider<UrlOpener>((ref) => _launch);

/// Never asks first whether a link can be opened (no canLaunchUrl), so no
/// Android `<queries>` and no iOS LSApplicationQueriesSchemes are needed. An
/// https link opens in the browser or its app; nothing is logged.
Future<bool> _launch(Uri uri) async {
  try {
    return await launchUrl(
      uri,
      mode: uri.scheme == 'https'
          ? LaunchMode.externalApplication
          : LaunchMode.platformDefault,
    );
  } on Object {
    return false;
  }
}
