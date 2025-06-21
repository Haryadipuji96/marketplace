import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../main.dart';
import 'add_product_screen.dart';
import 'product_detail_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'user_screen.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    fetchProducts();
    setupFCMListener();
  }

  Future<void> fetchProducts() async {
    final url = Uri.parse('http://10.10.201.241:81/api-produk/produk.php');
    try {
      final response = await http.get(url);
      print('Response produk: ${response.body}');
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);

        setState(() {
          _products = jsonData.map((item) => {
            'productId': item['id'].toString(),
            'name': item['nama'] ?? '-',
            'price': double.tryParse(item['harga']?.toString() ?? '0') ?? 0.0,
            'description': item['deskripsi'] ?? '',
            'location': item['lokasi'] ?? '',
            'imagePath': (item['gambar'] != null && item['gambar'].toString().isNotEmpty)
                ? 'http://10.10.201.241:81/api-produk/uploads/${item['gambar']}'
                : '',
            'uploaderId': item['uploader_id'] ?? '',
            'uploaderName': item['uploader_name'] ?? '',
          }).toList();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        throw Exception('Failed to load products');
      }
    } catch (e) {
      setState(() => _loading = false);
      print('Error fetching products: $e');
    }
  }

  void setupFCMListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showSimpleNotification(
          Text(message.notification!.title ?? 'Notifikasi'),
          subtitle: Text(message.notification!.body ?? ''),
          background: Colors.blue,
          duration: const Duration(seconds: 3),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      final data = message.data;
      final senderId = data['senderId'];
      final productId = data['productId'];

      if (senderId != null && productId != null) {
        final senderDoc =
        await FirebaseFirestore.instance.collection('users').doc(senderId).get();

        if (senderDoc.exists) {
          Navigator.push(
            navigatorKey.currentContext!,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                uploader: {
                  'uid': senderId,
                  'name': senderDoc.data()?['name'] ?? 'Pengguna',
                },
                productId: productId,
              ),
            ),
          );
        }
      }
    });
  }

  bool _isNetworkImage(String path) => path.startsWith('http');

  String formatPrice(double price) {
    if (price == price.toInt()) {
      return price.toInt().toString();
    } else {
      return price.toStringAsFixed(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NotificationsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: _products.isEmpty
          ? const Center(child: Text('Belum ada produk.'))
          : GridView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: _products.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 3 / 4,
        ),
        itemBuilder: (context, index) {
          final product = _products[index];

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(product: product),
                ),
              );
            },
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(10)),
                      child: _isNetworkImage(product['imagePath'])
                          ? Image.network(
                        product['imagePath'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                        const Center(child: Icon(Icons.broken_image)),
                      )
                          : const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('Rp ${formatPrice(product['price'] ?? 0.0)}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.home, color: Colors.blue),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.blue),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddProductScreen()),
                );

                if (result == true) {
                  fetchProducts();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.people, color: Colors.blue),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
