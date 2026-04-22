import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
}

/// Refresca go_router cuando cambia el AuthState en Riverpod.
class _AuthRouterNotifier extends ChangeNotifier {
  _AuthRouterNotifier(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (a, b) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRouterNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      // Bootstrap en curso → quedarse en splash.
      if (auth is AuthLoading) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // Autenticado: si está en splash/login/register → home.
      if (auth is AuthAuthenticated) {
        if (loc == AppRoutes.splash ||
            loc == AppRoutes.login ||
            loc == AppRoutes.register) {
          return AppRoutes.home;
        }
        return null;
      }

      // No autenticado: solo puede estar en login o register.
      if (loc == AppRoutes.login || loc == AppRoutes.register) return null;
      return AppRoutes.login;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (ctx, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (ctx, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (ctx, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (ctx, state) => const HomeScreen(),
      ),
    ],
  );
});
