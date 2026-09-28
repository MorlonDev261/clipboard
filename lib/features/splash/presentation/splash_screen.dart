import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';

/// Startup splash: the app logo with the app name below it, shown briefly
/// before the home screen takes over.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) context.go('/');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;
    // The logo sits at the exact centre — the same spot as the Android system
    // splash icon — so the hand-off from the system splash shows no jump; only
    // the name appears just below it.
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Image.asset(
              'assets/icon/icon.png',
              width: 132,
              height: 132,
              filterQuality: FilterQuality.medium,
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.16),
            child: Text(
              strings.appName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
