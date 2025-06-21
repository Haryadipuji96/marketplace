import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class LoginService extends ChangeNotifier {
  String _userId = '';
  String get userId => _userId;

  /// Login menggunakan email & password
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _userId = credential.user!.uid;

      // ✅ Simpan FCM Token
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await FirebaseFirestore.instance.collection('users').doc(_userId).set(
          {'fcmToken': fcmToken},
          SetOptions(merge: true),
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      print("Login error: $e");
      return false;
    }
  }

  /// Registrasi akun baru
  Future<bool> register(String email, String password) async {
    try {
      UserCredential credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _userId = credential.user!.uid;

      // ✅ Simpan FCM Token
      final fcmToken = await FirebaseMessaging.instance.getToken();

      await FirebaseFirestore.instance.collection('users').doc(_userId).set({
        'email': email,
        'name': '',
        'createdAt': FieldValue.serverTimestamp(),
        'fcmToken': fcmToken,
      });

      notifyListeners();
      return true;
    } catch (e) {
      print('Register error: $e');
      return false;
    }
  }

  /// Logout
  void logout() {
    FirebaseAuth.instance.signOut();
    _userId = '';
    notifyListeners();
  }
}
