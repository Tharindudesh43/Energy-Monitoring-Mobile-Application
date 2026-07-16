import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:energy_application/LocalNotificationService.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class Firebasemdg {
  final msgService = FirebaseMessaging.instance;

  initFCR() async {
    await msgService.requestPermission();

    var token = await msgService.getToken();
    print("FCM Token: $token");

    await saveTokenToFirestore(token);

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await saveTokenToFirestore(newToken);
    });

    FirebaseMessaging.onBackgroundMessage(handleNotification);
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      Future<void> saveNotification(RemoteMessage message) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .add({
              'title': message.notification?.title ?? '',
              'body': message.notification?.body ?? '',
              'data': message.data,
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
            });
      }

      print("Received a message in the foreground: ${message.messageId}");

      if (message.notification != null) {
        LocalNotificationService.showNotification(
          message.notification!.title ?? "No Title",
          message.notification!.body ?? "No Body",
        );
      }
    });
  }

  Future<void> saveTokenToFirestore(String? token) async {
    if (token == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }

  Future<void> handleNotification(RemoteMessage message) async {
    print("title: ${message.notification?.title}");
    print("Body: ${message.notification?.body}");
    print("Payload: ${message.data}");
  }
}
