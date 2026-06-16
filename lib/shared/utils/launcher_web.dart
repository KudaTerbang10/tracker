import 'dart:html' as html;

Future<void> openUrl(String url) async {
  html.window.open(url, '_blank');
}
