import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_card_wallet/core/security/integrity_checker.dart';
import 'package:my_card_wallet/core/security/session_manager.dart';
import 'package:my_card_wallet/features/auth/presentation/providers/auth_providers.dart';
import 'package:my_card_wallet/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:my_card_wallet/shared/router/app_router.dart';
import 'package:my_card_wallet/shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const ProviderScope(child: CardWalletApp()));
}

class CardWalletApp extends ConsumerStatefulWidget {
  const CardWalletApp({super.key});

  @override
  ConsumerState<CardWalletApp> createState() => _CardWalletAppState();
}

class _CardWalletAppState extends ConsumerState<CardWalletApp>
    with WidgetsBindingObserver {
  bool _isFirstLaunch = false;
  bool _initDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initialize() async {
    // Integrity check (non-blocking warning)
    final checker = IntegrityChecker();
    final status = await checker.check();
    if (status == IntegrityStatus.jailbroken) {
      // Will show warning after first frame
    }

    // Check first launch
    final authService = ref.read(authServiceProvider);
    final firstLaunch = await authService.isFirstLaunch();

    if (mounted) {
      setState(() {
        _isFirstLaunch = firstLaunch;
        _initDone = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Lock immediately when app goes to background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(sessionManagerProvider.notifier).lock();
      ref.read(isAuthenticatedProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initDone) {
      return MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_isFirstLaunch) {
      return MaterialApp(
        title: 'Card Wallet',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: OnboardingScreen(
          onComplete: () {
            if (mounted) setState(() => _isFirstLaunch = false);
          },
        ),
      );
    }

    final router = ref.watch(routerProvider);

    return GestureDetector(
      onTap: () => ref.read(sessionManagerProvider.notifier).onActivity(),
      onPanDown: (_) =>
          ref.read(sessionManagerProvider.notifier).onActivity(),
      child: MaterialApp.router(
        title: 'Card Wallet',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        builder: (context, child) =>
            _ScreenshotProtection(child: child ?? const SizedBox()),
      ),
    );
  }
}

class _ScreenshotProtection extends StatefulWidget {
  final Widget child;
  const _ScreenshotProtection({required this.child});

  @override
  State<_ScreenshotProtection> createState() => _ScreenshotProtectionState();
}

class _ScreenshotProtectionState extends State<_ScreenshotProtection> {
  @override
  void initState() {
    super.initState();
    // FLAG_SECURE is set natively in MainActivity.kt for Android.
    // iOS screenshot prevention is handled via the window's secureTextEntry trick (future enhancement).
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
