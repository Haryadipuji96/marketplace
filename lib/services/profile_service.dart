import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ProfileService {
  /// Fungsi untuk upload data profil ke server, termasuk gambar jika ada
  static Future<String?> uploadProfileData({
    required String uid,
    required String name,
    required String email,
    File? imageFile,
  }) async {
    // Validasi data kosong
    if (uid.isEmpty || name.isEmpty || email.isEmpty) {
      print("❌ UID, nama, atau email kosong");
      return null;
    }

    final uri = Uri.parse("http://10.10.201.241:81/api-produk/upload_profile.php");
    final request = http.MultipartRequest('POST', uri);

    request.fields['uid'] = uid;
    request.fields['name'] = name;
    request.fields['email'] = email;

    // Tambahkan file gambar jika ada
    if (imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath('foto_profil', imageFile.path));
    }

    try {
      final response = await request.send().timeout(const Duration(seconds: 10));
      final respStr = await response.stream.bytesToString();
      print("✅ Upload response: $respStr");

      final json = jsonDecode(respStr);
      if (json['success'] == true) {
        return json['foto_url']; // URL gambar profil yang diunggah
      } else {
        print("❌ Upload gagal: ${json['message']}");
        return null;
      }
    } catch (e) {
      print("❌ Upload error: $e");
      return null;
    }
  }

  /// Fungsi untuk mengambil data user berdasarkan UID dari API
  static Future<Map<String, dynamic>?> fetchUserByUid(String uid) async {
    if (uid.isEmpty) {
      print("❌ UID kosong, tidak bisa ambil user");
      return null;
    }

    final url = Uri.parse("http://10.10.201.241:81/api-produk/get_user_by_uid.php?uid=$uid");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print("❌ HTTP Error: ${response.statusCode}");
        return null;
      }

      final jsonBody = jsonDecode(response.body);

      if (jsonBody['success'] == true && jsonBody['user'] != null) {
        print("✅ User ditemukan: ${jsonBody['user']}");
        return jsonBody['user'];
      } else {
        print("❌ Gagal ambil user: ${jsonBody['message'] ?? 'Data tidak ditemukan'}");
        return null;
      }
    } catch (e) {
      print("❌ Error ambil user dari API: $e");
      return null;
    }
  }
}
