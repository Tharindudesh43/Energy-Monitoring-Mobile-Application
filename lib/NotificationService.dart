import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  Future<void> initNotifications() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ FCM Permissions Granted');

      _listenToTokenChanges();

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showInAppAlert(message);
      });
    }
  }

  void _listenToTokenChanges() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        String? token = await _fcm.getToken();
        if (token != null) await _saveTokenToDatabase(token, user.uid);
      }
    });

    _fcm.onTokenRefresh.listen((newToken) async {
      User? user = _auth.currentUser;
      if (user != null) await _saveTokenToDatabase(newToken, user.uid);
    });
  }

  Future<void> _saveTokenToDatabase(String token, String uid) async {
    try {
      await _db.collection('users').doc(uid).set({
        'fcm_token': token,
        'last_seen': FieldValue.serverTimestamp(),
        'platform': 'android',
      }, SetOptions(merge: true));
      debugPrint('📱 FCM Token Synced for UID: $uid');
    } catch (e) {
      debugPrint('❌ Firestore Error: $e');
    }
  }

  void _showInAppAlert(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text("${notification.title}: ${notification.body}"),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Background Message: ${message.messageId}");
}
