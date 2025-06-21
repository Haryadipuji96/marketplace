import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> uploader; // Berisi uid & name
  final String productId;

  const ChatScreen({
    Key? key,
    required this.uploader,
    required this.productId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final currentUser = FirebaseAuth.instance.currentUser!;
  late final String chatRoomId;
  late final String receiverId;

  bool isUidValid = true;

  @override
  void initState() {
    super.initState();

    receiverId = widget.uploader['uid'] ?? '';

    if (receiverId.isEmpty) {
      isUidValid = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('UID penjual kosong. Tidak dapat membuka chat.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      });
    } else {
      chatRoomId = getChatRoomId(currentUser.uid, receiverId, widget.productId);
    }
  }

  String getChatRoomId(String uid1, String uid2, String productId) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}_$productId';
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || !isUidValid) return;

    try {
      final message = {
        'senderId': currentUser.uid,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'productId': widget.productId,
      };

      final chatRef = FirebaseFirestore.instance.collection('chatRooms').doc(chatRoomId);

      await chatRef.collection('messages').add(message);

      await chatRef.set({
        'user1': currentUser.uid,
        'user2': receiverId,
        'productId': widget.productId,
        'lastMessage': text,
        'lastTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final notifDocId = '${currentUser.uid}_${widget.productId}';
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(receiverId)
          .collection('messages')
          .doc(notifDocId)
          .set({
        'senderId': currentUser.uid,
        'senderName': currentUser.displayName ?? 'Pengguna',
        'productId': widget.productId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Ambil FCM Token jika ada
      final sellerDoc = await FirebaseFirestore.instance.collection('users').doc(receiverId).get();
      final sellerToken = sellerDoc.data()?['fcmToken'];

      if (sellerToken != null) {
        await sendPushNotification(
          token: sellerToken,
          title: 'Pesan Baru dari ${currentUser.displayName ?? "Pengguna"}',
          body: text,
          senderId: currentUser.uid,
          productId: widget.productId,
        );
      }

      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim pesan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isUidValid) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.uploader['name'] ?? 'Chat'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chatRooms')
                  .doc(chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['senderId'] == currentUser.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[100] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(msg['text'] ?? ''),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ketik pesan...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onFieldSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 🔔 Kirim FCM Push Notification
Future<void> sendPushNotification({
  required String token,
  required String title,
  required String body,
  required String senderId,
  required String productId,
}) async {
  const serverKey = 'BBt7TKC5TMCql0lirC5Ubp56w8tPF24y4GtFmfgbtqnjJ7jSyxBde_ZeP-3-BClyrvg1--XycH_7wecioZtOXek	'; // Ganti dengan Server Key Firebase-mu

  try {
    await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      },
      body: jsonEncode({
        'to': token,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'senderId': senderId,
          'productId': productId,
        },
      }),
    );
  } catch (e) {
    debugPrint('❌ Gagal kirim notifikasi: $e');
  }
}
