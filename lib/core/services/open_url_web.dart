import 'dart:html' as html;

void openInNewTab(String url) {
  html.window.open(url, '_blank');
}

void navigateToUrl(String url) {
  html.window.location.href = url;
}

String getWebOrigin() => html.window.location.origin;
