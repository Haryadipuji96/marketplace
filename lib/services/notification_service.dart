import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> sendPushNotification({
  required String token,
  required String title,
  required String body,
  required String senderId,
}) async {
  const serverKey = 'BBt7TKC5TMCql0lirC5Ubp56w8tPF24y4GtFmfgbtqnjJ7jSyxBde_ZeP-3-BClyrvg1--XycH_7wecioZtOXek'; // 🔑 Ganti dengan server key Firebase kamu

  try {
    final response = await http.post(
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
          'senderId': senderId,
        },
      }),
    );

    if (response.statusCode != 200) {
      print('❌ Gagal kirim notifikasi. Status: ${response.statusCode}');
    } else {
      print('✅ Notifikasi berhasil dikirim.');
    }
  } catch (e) {
    print('❌ Error kirim notifikasi: $e');
  }
}
