import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../data/models/user.dart';

// ---- Infra providers ----
final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage());
final apiClientProvider =
    Provider<ApiClient>((ref) => ApiClient(ref.watch(tokenStorageProvider)));
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
      ref.watch(apiClientProvider),
      ref.watch(tokenStorageProvider),
    ));

// ---- Auth state ----
sealed class AuthState {
  const AuthState();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final User user;
  const AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {
  final String? message;
  const AuthUnauthenticated({this.message});
}

// ---- Controller ----
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo, this._tokens) : super(const AuthLoading()) {
    _bootstrap();
  }

  final AuthRepository _repo;
  final TokenStorage _tokens;

  Future<void> _bootstrap() async {
    final access = await _tokens.readAccess();
    if (access == null || access.isEmpty) {
      state = const AuthUnauthenticated();
      return;
    }
    final user = await _repo.me();
    if (user != null) {
      state = AuthAuthenticated(user);
    } else {
      await _tokens.clear();
      state = const AuthUnauthenticated();
    }
  }

  Future<void> login({required String telefono, required String password}) async {
    state = const AuthLoading();
    try {
      final result = await _repo.login(telefono: telefono, password: password);
      state = AuthAuthenticated(result.user);
    } on AuthException catch (e) {
      state = AuthUnauthenticated(message: e.message);
      rethrow;
    }
  }

  Future<void> register({
    required String telefono,
    required String nombres,
    required String password,
    String? apellidos,
    String? email,
  }) async {
    state = const AuthLoading();
    try {
      final result = await _repo.register(
        telefono: telefono,
        nombres: nombres,
        password: password,
        apellidos: apellidos,
        email: email,
      );
      state = AuthAuthenticated(result.user);
    } on AuthException catch (e) {
      state = AuthUnauthenticated(message: e.message);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthUnauthenticated();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(authRepositoryProvider),
    ref.watch(tokenStorageProvider),
  );
});
