import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/app_header_title.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/settings_providers.dart';
import '../application/reseller_providers.dart';
import '../data/reseller_config.dart';
import '../data/reseller_web_controller.dart';
import 'reseller_web_view.dart';

/// Home in "reseller" mode: the whole app body is the reseller space
/// (https://reseller.poma-original.com/*), under the usual header + badge.
class ResellerHome extends ConsumerStatefulWidget {
  const ResellerHome({super.key});

  @override
  ConsumerState<ResellerHome> createState() => _ResellerHomeState();
}

class _ResellerHomeState extends ConsumerState<ResellerHome> {
  ResellerWebController? _web;

  @override
  void initState() {
    super.initState();
    if (ResellerConfig.webViewSupported) {
      final pending = ref.read(pendingResellerUrlProvider);
      _web = ResellerWebController(
        initial: pending ?? ResellerConfig.homeUri,
        onSession: _onSession,
      );
      if (pending != null) {
        // The deep link is consumed by the initial load.
        Future.microtask(
            () => ref.read(pendingResellerUrlProvider.notifier).set(null));
      }
    }
  }

  @override
  void dispose() {
    _web?.dispose();
    super.dispose();
  }

  /// The hidden flag follows the real session: it is set while logged in and
  /// dropped when the session ends (logout, expiry).
  void _onSession(bool authenticated) {
    ref.read(settingsControllerProvider.notifier).setReseller(authenticated);
    final web = _web;
    if (authenticated && web != null) {
      unawaited(ref.read(resellerPushProvider).register(web.pushRequest));
    }
  }

  /// Confirms, wipes the WebView session, then returns to the clipboard space.
  Future<void> _signOut() async {
    final strings = ref.read(appStringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.resellerSignOutTitle),
        content: Text(strings.resellerSignOutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            key: const ValueKey('reseller-sign-out-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.resellerSignOut),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final web = _web;
    if (web != null) {
      // Before the cookie is wiped: the server needs the session to delete it.
      await ref.read(resellerPushProvider).unregister(web.pushRequest);
    }
    try {
      await _web?.clearSession();
    } catch (_) {
      // Even if the platform refuses to wipe, the app-side state is reset.
    }
    await ref.read(settingsControllerProvider.notifier).signOutReseller();
  }

  Future<void> _back() async {
    final web = _web;
    if (web != null && await web.goBack()) return;
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    // A deep link arriving while the space is already open.
    ref.listen<Uri?>(pendingResellerUrlProvider, (_, uri) {
      if (uri == null) return;
      unawaited(_web?.load(uri) ?? Future<void>.value());
      ref.read(pendingResellerUrlProvider.notifier).set(null);
    });

    final web = _web;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: AppHeaderTitle.heightWithBadge,
          title: const AppHeaderTitle(showModeBadge: true),
          actions: [
            IconButton(
              key: const ValueKey('reseller-sign-out'),
              tooltip: ref.watch(appStringsProvider).resellerSignOut,
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
            ),
            if (web != null)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: web.reload,
              ),
          ],
        ),
        body: web == null
            ? ResellerBrowserFallback(uri: ResellerConfig.homeUri)
            : ResellerWebView(controller: web),
      ),
    );
  }
}
