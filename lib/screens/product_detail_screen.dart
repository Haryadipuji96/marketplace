import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_screen.dart';
import '../services/profile_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late String receiverId;
  late String productId;
  Map<String, dynamic> uploader = {};
  bool isLoadingUploader = true;
  bool isFavorited = false;

  @override
  void initState() {
    super.initState();
    receiverId = widget.product['firebase_uid'] ?? '';
    productId = widget.product['id']?.toString() ?? '';

    print("🔥 receiverId: $receiverId");
    print("📦 product: ${widget.product}");

    loadUploader();
    checkFavorite();
  }

  Future<void> loadUploader() async {
    if (receiverId.isEmpty) {
      print("❌ UID kosong di produk");
      setState(() => isLoadingUploader = false);
      return;
    }

    print("🔄 Memanggil API untuk UID: $receiverId");
    final data = await ProfileService.fetchUserByUid(receiverId);

    if (data != null) {
      print("✅ Data pengguna dari API: $data");
      setState(() {
        uploader = data;
        isLoadingUploader = false;
      });
    } else {
      print("❌ Gagal mendapatkan data pengguna");
      setState(() => isLoadingUploader = false);
    }
  }

  Future<void> checkFavorite() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(productId)
        .get();

    setState(() {
      isFavorited = doc.exists;
    });
  }

  Future<void> toggleFavorite() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final favRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(productId);

    if (isFavorited) {
      await favRef.delete();
    } else {
      await favRef.set({
        'productId': productId,
        'timestamp': FieldValue.serverTimestamp(),
        ...widget.product,
      });
    }

    setState(() {
      isFavorited = !isFavorited;
    });
  }

  Future<void> deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: const Text('Apakah kamu yakin ingin menghapus produk ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('products').doc(productId).delete();
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk dihapus')));
      }
    }
  }

  String formatPrice(dynamic price) {
    double parsedPrice = 0;
    if (price is int) parsedPrice = price.toDouble();
    else if (price is double) parsedPrice = price;
    else parsedPrice = double.tryParse(price.toString()) ?? 0.0;
    return parsedPrice.toInt().toString();
  }

  void _openMap(String location) async {
    final encodedLocation = Uri.encodeComponent(location);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedLocation');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String getFullImagePath(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'http://10.10.201.241:81/api-produk/uploads/$path';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    final location = widget.product['location'] ?? '-';
    final imagePath = widget.product['imagePath'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Produk'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(isFavorited ? Icons.favorite : Icons.favorite_border),
            onPressed: toggleFavorite,
          ),
          if (currentUser?.uid == receiverId)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: deleteProduct,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[300],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (imagePath == null || imagePath.toString().isEmpty)
                    ? const Center(child: Icon(Icons.image_not_supported, size: 50))
                    : Image.network(
                  getFullImagePath(imagePath.toString()),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.product['name'] ?? '-',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Rp ${formatPrice(widget.product['price'])}',
              style: const TextStyle(fontSize: 18, color: Colors.green),
            ),
            const SizedBox(height: 16),
            const Text('Deskripsi:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(widget.product['description'] ?? '-', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const Text('Lokasi:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(location, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            uploader: {
                              'uid': receiverId,
                              'name': uploader['nama'] ?? 'Pengguna',
                            },
                            productId: productId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat),
                    label: const Text('Chat Penjual'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openMap(location),
                    icon: const Icon(Icons.map),
                    label: const Text('Lihat Lokasi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Diupload oleh:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                if (isLoadingUploader)
                  const CircleAvatar(
                    backgroundColor: Colors.grey,
                    radius: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else if ((uploader['foto_profil'] ?? '').toString().isNotEmpty)
                  CircleAvatar(
                    backgroundImage: NetworkImage(getFullImagePath(uploader['foto_profil'])),
                    radius: 24,
                  )
                else
                  const CircleAvatar(
                    backgroundColor: Colors.grey,
                    radius: 24,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      uploader['nama'] ?? 'Pengguna',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      uploader['email'] ?? '-',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
