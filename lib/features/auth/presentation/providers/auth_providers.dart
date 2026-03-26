import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:my_card_wallet/core/storage/secure_storage_service.dart';
import 'package:my_card_wallet/features/auth/domain/auth_service.dart';

final secureStorageProvider = Provider<SecureStorageService>(
  (_) => SecureStorageService(),
);

final localAuthProvider = Provider<LocalAuthentication>(
  (_) => LocalAuthentication(),
);

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    ref.read(localAuthProvider),
    ref.read(secureStorageProvider),
  );
});

// Tracks whether the app has completed the current session auth
final isAuthenticatedProvider = StateProvider<bool>((_) => false);

// Tracks PIN entry attempts for lockout
final pinAttemptsProvider = StateProvider<int>((_) => 0);
