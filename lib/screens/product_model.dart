class Produk {
  final String id;
  final String nama;
  final String harga;
  final String deskripsi;
  final String lokasi;
  final String gambar;
  final String firebaseUid;

  Produk({
    required this.id,
    required this.nama,
    required this.harga,
    required this.deskripsi,
    required this.lokasi,
    required this.gambar,
    required this.firebaseUid,
  });

  factory Produk.fromJson(Map<String, dynamic> json) {
    return Produk(
      id: json['id'],
      nama: json['nama'],
      harga: json['harga'],
      deskripsi: json['deskripsi'],
      lokasi: json['lokasi'],
      gambar: json['gambar'],
      firebaseUid: json['firebase_uid'],
    );
  }
}
