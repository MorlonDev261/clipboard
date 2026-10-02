import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'reseller_config.dart';

/// Sends a token registration / removal through the reseller WebView (so the
/// request carries the user's own Auth.js session). Implemented by
/// `ResellerWebController.pushRequest`.
typedef PushTokenRequest = Future<bool> Function(
    String method, String token, String platform);

/// Native push (FCM) for the reseller space. Uses the same Firebase project and
/// the same server endpoint as the poma-original app: the device token is
/// registered on `POST /api/push/native` and the server sends to it by user.
///
/// Everything degrades to a no-op when Firebase is not configured
/// (`google-services.json` absent) or on a platform without FCM.
class ResellerPush {
  ResellerPush();

  bool? _ready;
  Future<bool>? _starting;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  bool _tapsListening = false;
  String? _registered;

  /// FCM exists for Android and iOS only.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get platformName =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Initialises Firebase once. `false` when push cannot work here.
  Future<bool> start() {
    if (!supported) return Future.value(false);
    final ready = _ready;
    if (ready != null) return Future.value(ready);
    return _starting ??= _init();
  }

  Future<bool> _init() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      _ready = true;
    } catch (e) {
      // No google-services.json / GoogleService-Info.plist: push stays off.
      debugPrint('Push disabled: Firebase is not configured ($e)');
      _ready = false;
    }
    return _ready!;
  }

  /// Calls [onLink] with the reseller URL carried by a tapped notification
  /// (`data.actionUrl`), whether the app was running or launched by the tap.
  Future<void> listenForTaps(void Function(Uri uri) onLink) async {
    if (_tapsListening || !await start()) return;
    _tapsListening = true;
    void handle(RemoteMessage? m) {
      final uri = linkFromData(m?.data);
      if (uri != null) onLink(uri);
    }

    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(handle);
    try {
      handle(await FirebaseMessaging.instance.getInitialMessage());
    } catch (_) {}
  }

  /// Asks for the notification permission, then registers this installation's
  /// token for the signed-in reseller and keeps it fresh. Safe to call on every
  /// "session is active" signal.
  Future<void> register(PushTokenRequest request) async {
    if (!await start()) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _send(request, token);
      await _refreshSub?.cancel();
      _refreshSub = FirebaseMessaging.instance.onTokenRefresh
          .listen((t) => unawaited(_send(request, t)), onError: (_) {});
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }

  Future<void> _send(PushTokenRequest request, String token) async {
    if (_registered == token) return;
    if (await request('POST', token, platformName)) _registered = token;
  }

  /// On sign-out: removes the token server-side *before* the session cookie is
  /// wiped (afterwards the server would refuse), then drops the local token so
  /// the next account gets a fresh one. A device that signed out never keeps
  /// receiving the previous user's notifications.
  Future<void> unregister(PushTokenRequest request) async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    if (_ready != true) return;
    try {
      final token = _registered ?? await FirebaseMessaging.instance.getToken();
      if (token != null) await request('DELETE', token, platformName);
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('Push unregistration failed: $e');
    }
    _registered = null;
  }

  Future<void> dispose() async {
    await _refreshSub?.cancel();
    await _openedSub?.cancel();
  }

  /// The reseller-space URL in a notification payload, or `null`. Relative
  /// paths resolve against the reseller host; anything outside the trusted
  /// hosts (or not https) is ignored.
  @visibleForTesting
  static Uri? linkFromData(Map<String, dynamic>? data) {
    final raw = data?['actionUrl'];
    if (raw is! String || raw.length > 2048) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) return null;
    final resolved = ResellerConfig.homeUri.resolveUri(parsed);
    return ResellerConfig.isTrusted(resolved) ? resolved : null;
  }
}
