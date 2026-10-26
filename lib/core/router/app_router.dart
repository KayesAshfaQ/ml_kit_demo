import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/home/home_screen.dart';
import '../../features/text/text_provider.dart';
import '../../features/text/text_screen.dart';
import '../services/image_picker_service.dart';

GoRouter createAppRouter(ImagePickerService picker) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    // Providers belong to routes: popping a screen disposes its native detector.
    GoRoute(
      path: '/text',
      builder: (context, state) => ChangeNotifierProvider(
        create: (_) => TextProvider(picker),
        child: const TextScreen(),
      ),
    ),
    /* GoRoute(
      path: '/barcode',
      builder: (context, state) => ChangeNotifierProvider(
        create: (_) => BarcodeProvider(picker),
        child: const BarcodeScreen(),
      ),
    ),
    GoRoute(
      path: '/face',
      builder: (context, state) => ChangeNotifierProvider(
        create: (_) => FaceProvider(picker),
        child: const FaceScreen(),
      ),
    ), */
  ],
);
