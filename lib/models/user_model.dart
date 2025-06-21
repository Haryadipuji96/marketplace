import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String email;
  final String name;
  final DateTime createdAt;

  UserModel({
    required this.email,
    required this.name,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(), // pastikan ini Timestamp ke DateTime
    );
  }
}
