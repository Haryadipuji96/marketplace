// import 'dart:io';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
//
// class UploadProductScreen extends StatefulWidget {
//   const UploadProductScreen({super.key});
//
//   @override
//   State<UploadProductScreen> createState() => _UploadProductScreenState();
// }
//
// class _UploadProductScreenState extends State<UploadProductScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _priceController = TextEditingController();
//   final TextEditingController _descController = TextEditingController();
//   final TextEditingController _locationController = TextEditingController();
//
//   File? _imageFile;
//   bool isLoading = false;
//
//   Future<void> pickImage() async {
//     final picker = ImagePicker();
//     final picked = await picker.pickImage(source: ImageSource.gallery);
//     if (picked != null) {
//       setState(() {
//         _imageFile = File(picked.path);
//       });
//     }
//   }
//
//   Future<void> uploadProduct() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;
//
//     setState(() => isLoading = true);
//
//     try {
//       // Ambil data pengguna
//       final userData = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
//       final uploaderName = userData['name'] ?? '';
//       final profileImage = userData['profileImage'] ?? '';
//
//       // Upload gambar ke Storage
//       String? imageUrl;
//       if (_imageFile != null) {
//         final ref = FirebaseStorage.instance
//             .ref()
//             .child('product_images')
//             .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
//         await ref.putFile(_imageFile!);
//         imageUrl = await ref.getDownloadURL();
//       }
//
//       // Simpan data ke Firestore
//       final productRef = FirebaseFirestore.instance.collection('products').doc();
//       await productRef.set({
//         'productId': productRef.id,
//         'name': _nameController.text.trim(),
//         'price': int.tryParse(_priceController.text.trim()) ?? 0,
//         'description': _descController.text.trim(),
//         'location': _locationController.text.trim(),
//         'imagePath': imageUrl ?? '',
//         'uploaderId': user.uid,
//         'uploaderName': uploaderName,
//         'uploaderAvatar': profileImage,
//         'createdAt': FieldValue.serverTimestamp(),
//       });
//
//       if (context.mounted) {
//         Navigator.pop(context);
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Produk berhasil ditambahkan')),
//         );
//       }
//     } catch (e) {
//       print("Upload error: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Gagal menambahkan produk')),
//       );
//     }
//
//     setState(() => isLoading = false);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Tambah Produk'),
//         backgroundColor: Colors.blue,
//         foregroundColor: Colors.white,
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               GestureDetector(
//                 onTap: pickImage,
//                 child: Container(
//                   height: 180,
//                   width: double.infinity,
//                   decoration: BoxDecoration(
//                     border: Border.all(color: Colors.grey),
//                     borderRadius: BorderRadius.circular(12),
//                     color: Colors.grey[200],
//                   ),
//                   child: _imageFile != null
//                       ? Image.file(_imageFile!, fit: BoxFit.cover)
//                       : const Center(child: Icon(Icons.add_a_photo, size: 40)),
//                 ),
//               ),
//               const SizedBox(height: 20),
//               TextFormField(
//                 controller: _nameController,
//                 decoration: const InputDecoration(labelText: 'Nama Produk'),
//                 validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
//               ),
//               const SizedBox(height: 12),
//               TextFormField(
//                 controller: _priceController,
//                 keyboardType: TextInputType.number,
//                 decoration: const InputDecoration(labelText: 'Harga'),
//                 validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
//               ),
//               const SizedBox(height: 12),
//               TextFormField(
//                 controller: _descController,
//                 decoration: const InputDecoration(labelText: 'Deskripsi'),
//                 maxLines: 3,
//                 validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
//               ),
//               const SizedBox(height: 12),
//               TextFormField(
//                 controller: _locationController,
//                 decoration: const InputDecoration(labelText: 'Lokasi'),
//                 validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
//               ),
//               const SizedBox(height: 24),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton.icon(
//                   onPressed: uploadProduct,
//                   icon: const Icon(Icons.save),
//                   label: const Text('Simpan Produk'),
//                   style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(vertical: 14),
//                     backgroundColor: Colors.blue,
//                     foregroundColor: Colors.white,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
