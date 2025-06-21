import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'chat_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final notifRef = FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('messages')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifikasi"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: notifRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Belum ada notifikasi."));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final notif = docs[index];
              final data = notif.data() as Map<String, dynamic>;

              final senderId = data['senderId'] ?? '';
              final text = data['text'] ?? '-';
              final productId = data['productId'] ?? 'unknown';
              final timestamp = data['timestamp'] as Timestamp?;
              final timeString = timestamp != null
                  ? DateFormat('dd MMM yyyy HH:mm').format(timestamp.toDate())
                  : '';

              return ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(text),
                subtitle: Text('Dari: $senderId • $timeString'),
                onTap: () async {
                  try {
                    // Ambil data user pengirim
                    final userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(senderId)
                        .get();

                    if (userDoc.exists) {
                      final uploader = {
                        'uid': senderId,
                        'name': userDoc.data()?['name'] ?? 'Pengguna',
                      };

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            uploader: uploader,
                            productId: productId, // ✅ Tambahkan ini
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pengirim tidak ditemukan'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gagal membuka chat: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
