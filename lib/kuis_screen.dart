import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/app_services.dart';

class KuisScreen extends StatefulWidget {
  final String moduleId;
  final List<dynamic> kuisList;

  const KuisScreen({super.key, required this.moduleId, required this.kuisList});

  @override
  State<KuisScreen> createState() => _KuisScreenState();
}

class _KuisScreenState extends State<KuisScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isLoading = false;

  final Map<String, String> _jawaban = {};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _submitKuis() async {
    if (_jawaban.length < widget.kuisList.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap jawab semua soal terlebih dahulu!'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<String> listJawabanTerurut = [];
      for (int i = 0; i < widget.kuisList.length; i++) {
        String currentKey = i.toString();
        listJawabanTerurut.add(_jawaban[currentKey] ?? '');
      }

      final Map<String, dynamic> payload = {
        'module_id': widget.moduleId,
        'jawaban': listJawabanTerurut,
      };

      final res = await ApiClient.post(
        '/modules/${widget.moduleId}/submit-kuis',
        body: payload,
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = res.json;
        if (data is Map && data['success'] == true) {
          final result = data['data'] ?? {};
          AppSession.instance.notifyDataChanged();
          final int xp = result['xp_gained'] ?? 0;
          final int score = result['score'] ?? 100;

          setState(() => _isLoading = false);
          HapticFeedback.heavyImpact();

          _showRewardBottomSheet(
            score: score,
            xpGained: xp,
            isLevelUp: result['is_level_up'] ?? false,
            newLevel: result['level'] ?? 1,
          );
          return;
        }
      }

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengirim jawaban. Silakan coba lagi.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan jaringan.')),
      );
    }
  }

  // Desain modal diadaptasi dari halaman materi_read_screen.dart
  void _showRewardBottomSheet({
    required int score,
    required int xpGained,
    required bool isLevelUp,
    required int newLevel,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isLevelUp
                      ? Colors.orange.shade50
                      : Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLevelUp
                      ? Icons.emoji_events_rounded
                      : Icons.military_tech_rounded,
                  size: 64,
                  color: isLevelUp ? Colors.orange : Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Nilai Kuis: $score',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isLevelUp
                    ? 'Luar biasa! Kamu mencapai Level $newLevel.\n+$xpGained XP berhasil didapatkan.'
                    : 'Kuis selesai! Kamu mendapatkan +$xpGained XP.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Selesai',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
Future<bool> _onWillPop() async {
    HapticFeedback.lightImpact();
    final bool? shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'Keluar dari Kuis?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Progres jawabanmu saat ini mungkin tidak akan tersimpan. Yakin ingin keluar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Batal keluar
              child: Text(
                'Lanjutkan Kuis',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true), // Ya, keluar
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Ya, Keluar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    // Mengembalikan nilai true jika user memilih "Ya, Keluar" (boleh pop)
    // Mengembalikan nilai false jika user memilih "Lanjutkan Kuis" atau menutup dialog
    return shouldPop ?? false; 
  }
  
  @override
  Widget build(BuildContext context) {
    final primaryGreen = Theme.of(context).primaryColor;
    final totalSoal = widget.kuisList.length;
    final progress = (_currentIndex + 1) / totalSoal;

    if (totalSoal == 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kuis')),
        body: const Center(child: Text('Data kuis tidak ditemukan.')),
      );
    }

    return PopScope(
      canPop: false, // Menahan tombol kembali bawaan HP
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Memanggil dialog konfirmasi
        final bool shouldPop = await _onWillPop();

        if (shouldPop && context.mounted) {
          Navigator.pop(
            context,
          ); // Baru izinkan pop jika dialog mengembalikan true
        }
      },
      // 2. Scaffold ASLI ANDA SEBELUMNYA MENJADI child DARI PopScope
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          // 3. TAMBAHKAN TOMBOL BACK CUSTOM DI APPBAR
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () async {
              // Menjalankan logika PopScope secara manual saat tombol AppBar ditekan
              final bool shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            'Soal ${_currentIndex + 1} dari $totalSoal',
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
            ),
          ),
        ),
        body: PageView.builder(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalSoal,
          itemBuilder: (context, index) {
            final soal = widget.kuisList[index];
            // Mengambil array options dari Laravel
            final List<dynamic> optionsList = soal['options'] ?? [];

            // Helper untuk mengubah index 0,1,2,3 menjadi a,b,c,d
            const abjad = ['a', 'b', 'c', 'd', 'e'];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    soal['pertanyaan'] ?? 'Pertanyaan tidak tersedia',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Looping data opsi secara otomatis
                  if (optionsList.isNotEmpty)
                    ...optionsList.asMap().entries.map((entry) {
                      int optIndex = entry.key;
                      var optData = entry.value;

                      // Gunakan huruf a/b/c/d berdasarkan urutan, atau ambil dari database jika ada kolom khusus (misal optData['abjad'])
                      String optionKey = abjad[optIndex % abjad.length];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildOptionBox(
                          index,
                          optionKey,
                          optData['teks_opsi'] ?? 'Teks opsi kosong', // Sesuaikan dengan nama kolom di tabel options Anda
                          primaryGreen,
                        ),
                      );
                    })
                  else
                    const Text('Tidak ada opsi jawaban tersedia.'),
                ],
              ),
            );
          },
        ),

        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade100)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                if (_currentIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                              setState(() => _currentIndex--);
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text(
                        'Kembali',
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (_currentIndex > 0) const SizedBox(width: 16),

                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_jawaban[_currentIndex.toString()] == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Silakan pilih salah satu opsi.',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (_currentIndex < totalSoal - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                              setState(() => _currentIndex++);
                            } else {
                              _submitKuis();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _currentIndex < totalSoal - 1
                                ? 'Selanjutnya'
                                : 'Selesai & Kumpulkan',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionBox(
    int soalIndex,
    String optionKey,
    String optionText,
    Color primaryGreen,
  ) {
    final isSelected = _jawaban[soalIndex.toString()] == optionKey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            // Gunakan .toString() pada soalIndex
            _jawaban[soalIndex.toString()] = optionKey;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryGreen.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? primaryGreen : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? primaryGreen : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  optionKey.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  optionText,
                  style: TextStyle(
                    fontSize: 15,
                    color: isSelected ? Colors.black87 : Colors.grey.shade700,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
