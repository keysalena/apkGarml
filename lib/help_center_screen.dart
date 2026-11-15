import 'package:flutter/material.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryGreen = Theme.of(context).primaryColor;

    final List<Map<String, String>> faqs = [
      {
        'tanya': 'Bagaimana cara mendapatkan XP?',
        'jawab': 'Kamu bisa mendapatkan XP dengan cara menyelesaikan materi pembelajaran, menjawab kuis di akhir modul, dan mengerjakan tantangan tambahan.'
      },
      {
        'tanya': 'Mengapa kuis saya terkunci?',
        'jawab': 'Kuis pada sebuah modul baru bisa dibuka setelah kamu membaca dan menyelesaikan seluruh materi secara berurutan pada modul tersebut.'
      },
      {
        'tanya': 'Bagaimana cara mengubah profil?',
        'jawab': 'Buka halaman Profil (ikon orang di pojok kanan bawah), lalu pilih menu "Edit Profil" untuk memperbarui nama dan email.'
      },
      {
        'tanya': 'Bagaimana jika aplikasi mengalami kendala/error?',
        'jawab': 'Pastikan koneksi internet stabil. Jika masalah berlanjut, hubungi admin sistem Universitas Negeri Malang melalui email dukungan kampus.'
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Pusat Bantuan', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.support_agent_rounded, size: 40, color: primaryGreen),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Butuh bantuan tambahan? Temukan jawabannya di bawah ini.',
                      style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pertanyaan Umum (FAQ)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            ...faqs.map((faq) {
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ExpansionTile(
                  title: Text(faq['tanya']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  iconColor: primaryGreen,
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text(faq['jawab']!, style: TextStyle(color: Colors.grey.shade700, height: 1.5)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}