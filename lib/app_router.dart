import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/auth/auth_screen.dart';
import 'presentation/screens/auth/expired_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/live_tv/live_tv_screen.dart';
import 'presentation/screens/live_tv/player_screen.dart';
import 'presentation/screens/movies/movies_screen.dart';
import 'presentation/screens/movies/movie_detail_screen.dart';
import 'presentation/screens/movies/vod_player_screen.dart';
import 'presentation/screens/series/series_screen.dart';
import 'presentation/screens/series/series_detail_screen.dart';
import 'presentation/screens/favourites/favourites_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'domain/entities/vod.dart';
import 'domain/entities/series.dart';
import 'presentation/screens/activation/activation_screen.dart';

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    _sub = ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
  late final ProviderSubscription<AuthState> _sub;
  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

GoRouter buildRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc  = state.matchedLocation;

      if (auth is AuthUnknown || auth is AuthLoading) return null;
      if (auth is AuthAuthenticated) {
        return (loc == '/splash' || loc == '/auth' || loc == '/activation')
            ? '/home'
            : null;
      }
      if (auth is AuthExpired) return loc == '/expired'    ? null : '/expired';
      if (auth is AuthInitial) return loc == '/activation' ? null : '/activation';
      // AuthError → manual login
      return loc == '/auth' ? null : '/auth';
    },
    routes: [
      GoRoute(path: '/splash',     builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/auth',       builder: (_, __) => const AuthScreen()),
      GoRoute(path: '/activation', builder: (_, __) => const IzoActivationScreen()),
      GoRoute(path: '/expired',    builder: (_, __) => const ExpiredScreen()),
      GoRoute(path: '/home',       builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/live',
        builder: (_, __) => const LiveTvScreen(),
        routes: [
          GoRoute(
            path: 'player',
            pageBuilder: (_, __) => const NoTransitionPage(child: LivePlayerScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/movies',
        builder: (_, __) => const MoviesScreen(),
        routes: [
          // player MUST be declared BEFORE :id
          GoRoute(
            path: 'player',
            pageBuilder: (_, state) => NoTransitionPage(
              child: VodPlayerScreen(vod: state.extra as VodItem),
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return MovieDetailScreen(vodId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/series',
        builder: (_, __) => const SeriesScreen(),
        routes: [
          // player MUST be declared BEFORE :id
          GoRoute(
            path: 'player',
            pageBuilder: (_, state) {
              final extra    = state.extra as Map<String, dynamic>;
              final ep       = extra['episode']  as Episode;
              final episodes = extra['episodes'] as List<Episode>;
              final index    = extra['index']    as int;
              return NoTransitionPage(
                child: VodPlayerScreen(
                  vod: VodItem(
                    id:          ep.id,
                    name:        ep.title,
                    streamUrl:   ep.streamUrl,
                    categoryId:  0,
                    durationSecs: ep.durationSecs,
                  ),
                  episodes:     episodes,
                  episodeIndex: index,
                ),
              );
            },
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) {
              final id     = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              final series = state.extra as SeriesItem?;
              return SeriesDetailScreen(seriesId: id, series: series);
            },
          ),
        ],
      ),
      GoRoute(path: '/favourites', builder: (_, __) => const FavouritesScreen()),
      GoRoute(path: '/settings',   builder: (_, __) => const SettingsScreen()),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter(ref);
  ref.onDispose(router.dispose);
  return router;
});
