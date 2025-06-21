import 'dart:io';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:overlay_support/overlay_support.dart';

import 'services/login_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';

// Tambahkan global navigatorKey
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📩 Notifikasi background: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBLeARzC8VCh8gFC9G8PKgNVcZ7w37dfoU",
      authDomain: "flutter-marketplace-b42be.firebaseapp.com",
      projectId: "flutter-marketplace-b42be",
      storageBucket: "flutter-marketplace-b42be.appspot.com",
      messagingSenderId: "997640855551",
      appId: "1:997640855551:web:6814a35e6048ed83add1ca",
    ),
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Channel untuk notifikasi penting',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: initSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      final payload = response.payload;
      if (payload != null) {
        final data = payload.split('|'); // Format: senderId|productId
        if (data.length == 2) {
          final senderId = data[0];
          final productId = data[1];

          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(senderId)
              .get();

          if (userDoc.exists) {
            final uploader = {
              'uid': senderId,
              'name': userDoc.data()?['name'] ?? 'Pengguna',
            };

            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) =>
                    ChatScreen(uploader: uploader, productId: productId),
              ),
            );
          }
        }
      }
    },
  );

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();

  final fcmToken = await messaging.getToken();
  print("✅ FCM Token: $fcmToken");

  final user = FirebaseAuth.instance.currentUser;
  if (user != null && fcmToken != null) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'fcmToken': fcmToken}, SetOptions(merge: true));
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        final title = message.notification!.title ?? 'Notifikasi';
        final body = message.notification!.body ?? '';
        final senderId = message.data['senderId'] ?? '';
        final productId = message.data['productId'] ?? '';

        flutterLocalNotificationsPlugin.show(
          0,
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              channelDescription: 'Channel untuk notifikasi penting',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: '$senderId|$productId', // Format payload baru
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      print('📬 App dibuka dari notifikasi');
      final senderId = message.data['senderId'];
      final productId = message.data['productId'];
      if (senderId != null && productId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(senderId)
            .get();

        if (userDoc.exists) {
          final uploader = {
            'uid': senderId,
            'name': userDoc.data()?['name'] ?? 'Pengguna',
          };

          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                uploader: uploader,
                productId: productId,
              ),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return OverlaySupport.global(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'SecondHand Market',
        theme: ThemeData(primarySwatch: Colors.blue),
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Image.asset(
                  'assets/Marketplace1.png',
                  width: 160,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
