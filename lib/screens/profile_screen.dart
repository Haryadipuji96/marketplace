import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:share_plus/share_plus.dart';
import '../services/profile_service.dart';
import 'login_screen.dart';
import 'product_detail_screen.dart';
import 'package:http/http.dart' as http;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool isLoading = false;
  File? selectedImageFile;
  late TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => selectedImageFile = File(picked.path));
    }
  }

  Future<String?> uploadImage(File file) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images/${user!.uid}.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Upload failed: $e");
      return null;
    }
  }

  Future<void> _editProfile(Map<String, dynamic> userData) async {
    _nameController.text = userData['name'] ?? '';
    _bioController.text = userData['bio'] ?? '';
    selectedImageFile = null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Edit Profil"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picked = await _picker.pickImage(source: ImageSource.gallery);
                      if (picked != null) {
                        setState(() => selectedImageFile = File(picked.path));
                        setStateDialog(() {});
                      }
                    },
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: selectedImageFile != null
                          ? FileImage(selectedImageFile!)
                          : (userData['profileImage'] != null
                          ? NetworkImage(userData['profileImage'])
                          : null) as ImageProvider<Object>?,
                      child: (selectedImageFile == null &&
                          userData['profileImage'] == null)
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "Nama"),
                  ),
                  TextField(
                    controller: _bioController,
                    decoration: const InputDecoration(labelText: "Bio"),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal")),
              TextButton(
                onPressed: () async {
                  setStateDialog(() => isLoading = true); // loading aktif

                  final name = _nameController.text.trim();
                  final bio = _bioController.text.trim();

                  try {
                    // 1. Simpan ke Firestore (name dan bio)
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user!.uid)
                        .update({
                      'name': name,
                      'bio': bio,
                    });

                    // 2. Simpan ke API (nama, email, foto)
                    final fotoUrl = await ProfileService.uploadProfileData(
                      uid: user!.uid,
                      name: name,
                      email: user!.email ?? '',
                      imageFile: selectedImageFile,
                    );

// Update foto ke Firestore jika berhasil
                    if (fotoUrl != null && fotoUrl.isNotEmpty) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user!.uid)
                          .update({'profileImage': fotoUrl});
                    }


                    // 3. Tutup modal jika berhasil
                    if (context.mounted) {
                      Navigator.pop(context);
                      setState(() {}); // ⬅️ REFRESH halaman setelah simpan
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Profil berhasil diperbarui")),
                      );
                    }
                  } catch (e) {
                    print("❌ Error simpan profil: $e");

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Gagal memperbarui profil")),
                      );
                    }
                  } finally {
                    setStateDialog(() => isLoading = false); // loading selesai
                  }
                },
                child: const Text("Simpan"),
              ),

            ],
          );
        },
      ),
    );
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Yakin ingin keluar?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Tidak")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Ya")),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  void _shareProfile(String name, String bio) {
    Share.share("Profil saya:\nNama: $name\nBio: $bio");
  }

  Future<void> _deleteProduct(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Produk"),
        content: const Text("Yakin ingin menghapus produk ini?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Tidak")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Ya")),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(docId)
          .delete();
    }
  }

  Widget _buildProductList(Stream<QuerySnapshot> stream,
      {bool showDelete = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final products = snapshot.data!.docs;

        if (products.isEmpty) {
          return const Text("Tidak ada produk.");
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final data = products[index].data() as Map<String, dynamic>;
            final id = products[index].id;

            return Card(
              child: ListTile(
                leading: data['imagePath'] != null
                    ? Image.network(
                  data['imagePath'],
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                )
                    : const Icon(Icons.image_not_supported),
                title: Text(data['name'] ?? 'Produk'),
                subtitle: Text('Rp ${data['price'] ?? '0'}'),
                trailing: showDelete
                    ? IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteProduct(id),
                )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(product: data),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = user!.uid;
    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDoc.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final userData = snapshot.data!.data()!;
        final imageUrl = userData['profileImage'];
        final name = userData['name'] ?? 'User';
        final bio = userData['bio'] ?? '';

        return Scaffold(
          appBar: AppBar(
            title: const Text("Profil"),
            actions: [
              IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
              IconButton(
                  onPressed: () => _shareProfile(name, bio),
                  icon: const Icon(Icons.share)),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: "Tawaran"),
                Tab(text: "Favorit"),
              ],
            ),
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
            controller: _tabController,
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: imageUrl != null
                          ? NetworkImage(imageUrl)
                          : null,
                      child: imageUrl == null
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(name, style: const TextStyle(fontSize: 22)),
                    Text(user!.email ?? '',
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 10),
                    Text(bio, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    ElevatedButton(
                        onPressed: () => _editProfile(userData),
                        child: const Text("Edit Profil")),
                    const SizedBox(height: 20),
                    const Divider(),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Produk Anda",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                    _buildProductList(
                      FirebaseFirestore.instance
                          .collection('products')
                          .where('firebase_uid', isEqualTo: uid)
                          .snapshots(),
                      showDelete: true,
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildProductList(
                  FirebaseFirestore.instance
                      .collection('products')
                      .where('likes', arrayContains: uid)
                      .snapshots(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
