import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/splash_screen.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/provider/google_map_provider.dart';
import 'package:rider_ride_hailing_app/provider/notification_provider.dart';
import 'package:rider_ride_hailing_app/contants/theme_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Error widget pour debug
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 100, color: Colors.white),
              SizedBox(height: 20),
              Text(
                'Erreur de démarrage',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
              SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  details.exception.toString(),
                  style: TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  try {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    // Initialiser Firebase avec gestion d'erreur
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print("✅ Firebase initialized successfully");
    } catch (e) {
      print("❌ Firebase initialization error: $e");
      // Continue sans Firebase pour le moment
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CustomAuthProvider()),
          ChangeNotifierProvider(create: (_) => DarkThemeProvider()),
          ChangeNotifierProvider(create: (_) => TripProvider()),
          ChangeNotifierProvider(create: (_) => GoogleMapProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e, stack) {
    print("❌ Main error: $e");
    print("Stack: $stack");
    
    // Afficher une app d'erreur
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.orange,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning, size: 100, color: Colors.white),
                SizedBox(height: 20),
                Text(
                  'Erreur au démarrage',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    e.toString(),
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<DarkThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Misy',
          theme: Styles.themeData(themeProvider.darkTheme, context),
          debugShowCheckedModeBanner: false,
          navigatorKey: MyGlobalKeys.navigatorKey,
          home: const SplashScreen(),
          builder: EasyLoading.init(),
        );
      },
    );
  }
}