import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'reseller_config.dart';

/// Owns the platform WebView for the reseller space: confines navigation to
/// trusted hosts, opens everything else in the system, and reports whether an
/// Auth.js session exists after each page load.
class ResellerWebController {
  ResellerWebController({
    required Uri initial,
    required this.onSession,
  }) {
    web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('PomaSession', onMessageReceived: _onMessage)
      ..addJavaScriptChannel('PomaPush', onMessageReceived: _onPushMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => progress.value = p,
        onPageStarted: (_) {
          error.value = false;
        },
        onPageFinished: (url) {
          progress.value = 100;
          final uri = Uri.tryParse(url);
          if (uri != null && ResellerConfig.isTrusted(uri)) {
            web.runJavaScript(ResellerConfig.sessionProbe(_nonce));
          }
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) error.value = true;
        },
        onNavigationRequest: _onNavigationRequest,
      ))
      ..loadRequest(initial);
  }

  late final WebViewController web;

  /// Secret shared with the probe script injected by us (see
  /// [ResellerConfig.sessionProbe]).
  final String _nonce = _newNonce();

  static String _newNonce() {
    final r = Random.secure();
    return List.generate(
        16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// Called with `true` / `false` each time the session probe answers.
  final ValueChanged<bool> onSession;

  final progress = ValueNotifier<int>(0);
  final error = ValueNotifier<bool>(false);

  void _onMessage(JavaScriptMessage m) {
    try {
      final data = jsonDecode(m.message);
      if (data is Map && data['n'] == _nonce && data['a'] is bool) {
        onSession(data['a'] as bool);
      }
    } catch (_) {
      // ignore malformed messages
    }
  }

  Completer<bool>? _pushAck;

  void _onPushMessage(JavaScriptMessage m) {
    try {
      final data = jsonDecode(m.message);
      if (data is Map && data['n'] == _nonce && data['ok'] is bool) {
        final ack = _pushAck;
        _pushAck = null;
        if (ack != null && !ack.isCompleted) ack.complete(data['ok'] as bool);
      }
    } catch (_) {
      // ignore malformed messages
    }
  }

  /// Registers / removes a push token through the page (see
  /// [ResellerConfig.pushRequest]). `false` on any failure or after 5 s.
  Future<bool> pushRequest(String method, String token, String platform) async {
    final previous = _pushAck;
    if (previous != null && !previous.isCompleted) previous.complete(false);
    final ack = _pushAck = Completer<bool>();
    try {
      await web.runJavaScript(
          ResellerConfig.pushRequest(_nonce, method, token, platform));
    } catch (_) {
      return false;
    }
    return ack.future
        .timeout(const Duration(seconds: 5), onTimeout: () => false);
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    // Frames inside a page (embeds, payment widgets) are page content.
    if (!request.isMainFrame) return NavigationDecision.navigate;
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (request.url == 'about:blank') return NavigationDecision.navigate;
    if (ResellerConfig.isTrusted(uri)) return NavigationDecision.navigate;
    // Payment pages, WhatsApp, mail, phone…: hand over to the system — but only
    // known-safe schemes (never `intent:`, `file:`, `javascript:`, `data:`).
    if (ResellerConfig.externalSchemes.contains(uri.scheme)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return NavigationDecision.prevent;
  }

  /// Wipes everything the WebView keeps for the site: cookies (the Auth.js
  /// session), local/session storage and the HTTP cache.
  Future<void> clearSession() async {
    await WebViewCookieManager().clearCookies();
    await web.clearLocalStorage();
    await web.clearCache();
  }

  Future<void> load(Uri uri) => web.loadRequest(uri);

  Future<void> reload() async {
    error.value = false;
    await web.reload();
  }

  /// Goes back inside the site; `false` when there is no history left.
  Future<bool> goBack() async {
    if (await web.canGoBack()) {
      await web.goBack();
      return true;
    }
    return false;
  }

  void dispose() {
    progress.dispose();
    error.dispose();
  }
}
