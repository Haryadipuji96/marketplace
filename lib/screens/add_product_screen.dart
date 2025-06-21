import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String? _imagePath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    Location location = Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    try {
      final locData = await location.getLocation();
      if (locData.latitude != null && locData.longitude != null) {
        setState(() {
          _locationController.text =
          '${locData.latitude!.toStringAsFixed(6)}, ${locData.longitude!.toStringAsFixed(6)}';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil lokasi: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  Future<void> _submitProduct() async {
    final name = _nameController.text.trim();
    final priceText = _priceController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();

    if (name.isEmpty ||
        priceText.isEmpty ||
        description.isEmpty ||
        _imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua data produk')),
      );
      return;
    }

    final price = int.tryParse(priceText);
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harga harus berupa angka positif')),
      );
      return;
    }

    // Dapatkan pengguna Firebase login
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengguna belum login')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final uri = Uri.parse('http://10.10.201.241:81/api-produk/upload.php');

      var request = http.MultipartRequest('POST', uri);
      request.fields['nama'] = name;
      request.fields['harga'] = price.toString();
      request.fields['deskripsi'] = description;
      request.fields['lokasi'] = location;
      request.fields['firebase_uid'] = user.uid; // 🔥 Penting

      var multipartFile = await http.MultipartFile.fromPath(
        'gambar',
        _imagePath!,
        filename: path.basename(_imagePath!),
      );
      request.files.add(multipartFile);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = response.body.toLowerCase();
        if (responseData.contains('success')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produk berhasil ditambahkan!')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal tambah produk: ${response.body}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error server: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Produk'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  color: Colors.grey[200],
                ),
                child: _imagePath == null
                    ? const Center(child: Icon(Icons.add_a_photo, size: 80))
                    : Image.file(File(_imagePath!), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nama Produk'),
            ),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Harga'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Deskripsi'),
              maxLines: 3,
            ),
            TextField(
              controller: _locationController,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Lokasi (Otomatis)'),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _submitProduct,
              icon: const Icon(Icons.upload),
              label: const Text('Tambahkan Produk'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            )
          ],
        ),
      ),
    );
  }
}
