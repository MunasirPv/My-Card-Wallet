import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_card_wallet/features/auth/presentation/providers/auth_providers.dart';
import 'package:my_card_wallet/features/auth/presentation/screens/lock_screen.dart';
import 'package:my_card_wallet/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:my_card_wallet/features/auth/presentation/screens/pin_screen.dart';
import 'package:my_card_wallet/features/cards/presentation/screens/add_card_screen.dart';
import 'package:my_card_wallet/features/cards/presentation/screens/card_list_screen.dart';
import 'package:my_card_wallet/features/settings/presentation/screens/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  return GoRouter(
    initialLocation: '/lock',
    redirect: (context, state) {
      final authenticated = isAuthenticated;
      final onAuth = state.matchedLocation.startsWith('/lock') ||
          state.matchedLocation.startsWith('/onboarding') ||
          state.matchedLocation.startsWith('/pin');

      if (!authenticated && !onAuth) return '/lock';
      if (authenticated && state.matchedLocation == '/lock') return '/cards';
      return null;
    },
    routes: [
      GoRoute(
        path: '/lock',
        builder: (context, state) => const LockScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/pin/setup',
        builder: (context, state) => const PinScreen(isSetup: true),
      ),
      GoRoute(
        path: '/cards',
        builder: (context, state) => const CardListScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) => const AddCardScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (_, state) =>
                AddCardScreen(editCardId: state.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
