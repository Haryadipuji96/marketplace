import 'dart:convert';
import 'package:http/http.dart' as http;
import '../screens/product_model.dart';


class ProdukService {
  static const String _baseUrl = 'http://10.10.201.241:81/api-produk';

  static Future<List<Produk>> fetchProduk() async {
    final response = await http.get(Uri.parse('$_baseUrl/list.php'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Produk.fromJson(json)).toList();
    } else {
      throw Exception('Gagal memuat produk');
    }
  }
}
