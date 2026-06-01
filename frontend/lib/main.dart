import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/providers/auth_provider.dart';
import 'core/providers/home_provider.dart';
import 'core/providers/user_provider.dart';
import 'core/providers/like_provider.dart';
import 'core/providers/follow_provider.dart';
import 'core/services/cart_service.dart';
import 'core/services/favorite_service.dart';

import 'core/services/firebase_notification_handler.dart';
import 'core/navigation/app_navigator.dart';

import 'features/auth/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // If `.env` isn't present (e.g. CI or a fresh clone), Gemini keys will be missing.
  }

  // Lock app orientation
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Firebase initialization
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCE48KrWhufpijbyieG4-hVubHkeWt0R3Q",
        authDomain: "yummy-d1eb2.firebaseapp.com",
        projectId: "yummy-d1eb2",
        storageBucket: "yummy-d1eb2.firebasestorage.app",
        messagingSenderId: "783921216828",
        appId: "1:783921216828:web:4c6dc62f4281bb1f3ab239",
      ),
    );

    await setupFirebaseNotifications();
  } else {
    await Firebase.initializeApp();

    await setupFirebaseNotifications();
  }

  await CartService.init();
  await FavoriteService.loadFavorites();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => LikeProvider()),
        ChangeNotifierProvider(create: (_) => FollowProvider()),
      ],
      child: const YummyApp(),
    ),
  );
}

class YummyApp extends StatelessWidget {
  const YummyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Yummy',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xffF4F8FD),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      home: const SplashScreen(),
    );
  }
}
