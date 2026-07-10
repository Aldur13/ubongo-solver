import 'package:go_router/go_router.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

import 'data/scanned_board_data.dart';
import 'screens/camera_scan_screen.dart';
import 'screens/grid_markup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/manual_entry_screen.dart';
import 'screens/piece_selection_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/solution_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/manual', builder: (context, state) => const ManualEntryScreen()),
    GoRoute(path: '/scan', builder: (context, state) => const CameraScanScreen()),
    GoRoute(
      path: '/pieces',
      builder: (context, state) => PieceSelectionScreen(corrected: state.extra as CorrectedCardImage),
    ),
    GoRoute(
      path: '/markup',
      builder: (context, state) => GridMarkupScreen(data: state.extra as ScannedBoardData),
    ),
    GoRoute(path: '/solution', builder: (context, state) => const SolutionScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
  ],
);
