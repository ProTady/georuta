import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/tickets/data/models/boleto.dart';
import '../../features/tickets/data/models/reserva.dart';
import '../../features/tickets/presentation/boleto_detalle_screen.dart';
import '../../features/tickets/presentation/confirmar_reserva_screen.dart';
import '../../features/tickets/presentation/mis_boletos_screen.dart';
import '../../features/tickets/presentation/viaje_detalle_screen.dart';
import '../../features/trips/presentation/trip_search_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const search = '/search';
  // Rutas parametrizadas: se usan como "$viaje/<id>", "$reserva/<id>", "$boleto/<id>"
  static const viaje = '/viaje';
  static const reserva = '/reserva';
  static const boletos = '/boletos';
  static const boleto = '/boleto';
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

      if (auth is AuthLoading) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      if (auth is AuthAuthenticated) {
        if (loc == AppRoutes.splash ||
            loc == AppRoutes.login ||
            loc == AppRoutes.register) {
          return AppRoutes.home;
        }
        return null;
      }

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
      GoRoute(
        path: AppRoutes.search,
        builder: (ctx, state) => const TripSearchScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.viaje}/:id',
        builder: (ctx, state) =>
            ViajeDetalleScreen(viajeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${AppRoutes.reserva}/:id',
        builder: (ctx, state) => ConfirmarReservaScreen(
          reservaId: state.pathParameters['id']!,
          reservaInicial: state.extra is Reserva ? state.extra as Reserva : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.boletos,
        builder: (ctx, state) => const MisBoletosScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.boleto}/:id',
        builder: (ctx, state) {
          final extra = state.extra;
          if (extra is Boleto) return BoletoDetalleScreen(boleto: extra);
          // Fallback: si no viene por extra, redirigimos a la lista.
          return const MisBoletosScreen();
        },
      ),
    ],
  );
});
