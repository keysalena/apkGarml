
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import 'services/app_services.dart';
import 'kuis_screen.dart';
import 'materi_read_screen.dart';

class ModuleDetailScreen extends StatefulWidget {
  final String moduleId;
  final String moduleTitle;

  const ModuleDetailScreen({
    super.key,
    required this.moduleId,
    required this.moduleTitle,
  });

  @override
  State<ModuleDetailScreen> createState() => _ModuleDetailScreenState();
}

class _ModuleDetailScreenState extends State<ModuleDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _pendahuluan;
  List<dynamic> _materiList = [];
  List<dynamic> _kuisList = [];
  List<String> _completedMateriIds = [];
  bool _isKuisSelesai = false; // Tambahkan ini
  int _nilaiKuis = 0; // Tambahkan ini

  late final String _cacheKey = 'cache_module_${widget.moduleId}';
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  // Data tersimpan tampil dulu (tanpa spinner), lalu disegarkan di belakang layar.
  Future<void> _init() async {
    final cached = await LocalCache.load(_cacheKey);
    if (cached is Map && mounted) {
      setState(() {
        _applyDetail(Map<String, dynamic>.from(cached));
        _isLoading = false;
      });
    }
    await _fetchModuleDetail();
  }

  void _applyDetail(Map<String, dynamic> d) {
    _pendahuluan = d['pendahuluan'];
    _materiList = d['materi'] ?? [];
    _kuisList = d['kuis'] ?? [];
    _completedMateriIds = List<String>.from(
      (d['completed_materi_ids'] ?? []).map((e) => e.toString()),
    );
    _isKuisSelesai = d['kuis_selesai'] ?? false;
    _nilaiKuis = d['kuis_score'] ?? 0;
  }

  // Tambahkan parameter isManualRefresh
  Future<void> _fetchModuleDetail({bool isManualRefresh = false}) async {
    // Abaikan cegatan jika user menarik layar secara manual
    if (_isFetching && !isManualRefresh) return;
    
    _isFetching = true;
    try {
      final res = await ApiClient.get('/modules/${widget.moduleId}');
      if (!mounted) return;

      if (res.isSuccess && res.json['data'] is Map) {
        final d = Map<String, dynamic>.from(res.json['data']);
        setState(() {
          _applyDetail(d);
          _isLoading = false;
        });
        LocalCache.save(_cacheKey, d);
      } else {
        if (_isLoading) setState(() => _isLoading = false);
        if (isManualRefresh && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memperbarui data modul.')),
          );
        }
      }
    } catch (e) {
      if (_isLoading && mounted) setState(() => _isLoading = false);
      if (isManualRefresh && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terjadi kesalahan jaringan.')),
        );
      }
    } finally {
      _isFetching = false;
    }
  }

  IconData _getMateriIcon(String tipe) {
    switch (tipe.toLowerCase()) {
      case 'video':
        return Icons.play_circle_fill_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      default:
        return Icons.article_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          widget.moduleTitle,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : RefreshIndicator(
              color: primaryGreen,
              onRefresh: () async {
                await _fetchModuleDetail(isManualRefresh: true);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==========================================
                    // 1. KONTEN PENDAHULUAN (Mendukung HTML)
                    // ==========================================
                    if (_pendahuluan != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.rocket_launch_rounded,
                                  color: Colors.blue.shade700,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _pendahuluan!['judul'] ?? 'Pendahuluan',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            HtmlWidget(
                              _pendahuluan!['konten_teks'] ??
                                  'Isi pendahuluan belum tersedia.',
                              textStyle: const TextStyle(
                                fontSize: 14.0,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                              customStylesBuilder: (element) {
                                // Menghilangkan margin bawah bawaan tag <p> agar lebih rapi
                                if (element.localName == 'p') {
                                  return {
                                    'margin-bottom': '8px',
                                    'margin-top': '0px',
                                  };
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // ==========================================
                    // 2. KOTAK LIST MATERI UTAMA
                    // ==========================================
                    const Text(
                      'Materi Pembelajaran',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_materiList.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Belum ada materi di modul ini.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _materiList.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final materi = _materiList[index];
                          final String materiIdStr = materi['materi_id']
                              .toString();

                          final bool isCompleted = _completedMateriIds.contains(
                            materiIdStr,
                          );

                          bool isLocked = false;
                          if (index > 0) {
                            final String prevMateriId =
                                _materiList[index - 1]['materi_id'].toString();
                            if (!_completedMateriIds.contains(prevMateriId)) {
                              isLocked = true;
                            }
                          }

                          final String tipe = materi['tipe'] ?? 'teks';

                          return _buildMateriBox(
                            context: context,
                            materi: materi,
                            isCompleted: isCompleted,
                            isLocked: isLocked,
                            tipe: tipe,
                            primaryGreen: primaryGreen,
                            index: index + 1,
                          );
                        },
                      ),

                    const SizedBox(height: 40),

                    // ==========================================
                    // 3. SEKSI KUIS
                    // ==========================================
                    if (_kuisList.isNotEmpty) ...[
                      const Text(
                        'Tantangan Modul',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Builder(
                        builder: (context) {
                          bool allMateriCompleted = _materiList.every(
                            (m) => _completedMateriIds.contains(
                              m['materi_id'].toString(),
                            ),
                          );

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                if (!allMateriCompleted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Selesaikan semua materi terlebih dahulu untuk membuka kuis!',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                // Jika kuis sudah selesai, jangan izinkan klik lagi (opsional)
                                if (_isKuisSelesai) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Anda sudah menyelesaikan kuis ini.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                HapticFeedback.heavyImpact();

                                // Arahkan ke layar Kuis
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => KuisScreen(
                                      moduleId: widget.moduleId,
                                      kuisList: _kuisList,
                                    ),
                                  ),
                                ).then((result) {
                                  // Memuat ulang data modul jika kuis berhasil diselesaikan
                                  if (result == true) {
                                    _fetchModuleDetail();
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  // Ubah warna jika sudah selesai
                                  gradient: LinearGradient(
                                    colors: _isKuisSelesai
                                        ? [
                                            primaryGreen,
                                            primaryGreen.withValues(alpha: 0.8),
                                          ]
                                        : (allMateriCompleted
                                              ? [
                                                  Colors.orange.shade400,
                                                  Colors.deepOrange.shade400,
                                                ]
                                              : [
                                                  Colors.grey.shade400,
                                                  Colors.grey.shade500,
                                                ]),
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    if (allMateriCompleted && !_isKuisSelesai)
                                      BoxShadow(
                                        color: Colors.orange.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    if (_isKuisSelesai)
                                      BoxShadow(
                                        color: primaryGreen.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _isKuisSelesai
                                            ? Icons.check_circle_rounded
                                            : (allMateriCompleted
                                                  ? Icons.emoji_events_rounded
                                                  : Icons.lock_rounded),
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _isKuisSelesai
                                                ? 'Kuis Selesai'
                                                : 'Kuis Evaluasi Akhir',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _isKuisSelesai
                                                ? 'Nilai Anda: $_nilaiKuis' // Menampilkan nilai
                                                : (allMateriCompleted
                                                      ? 'Uji pemahamanmu dengan ${_kuisList.length} soal'
                                                      : 'Terkunci'),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.white.withValues(
                                                alpha: 0.9,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (allMateriCompleted && !_isKuisSelesai)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Text(
                                          'Mulai',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepOrange,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMateriBox({
    required BuildContext context,
    required dynamic materi,
    required bool isCompleted,
    required bool isLocked,
    required String tipe,
    required Color primaryGreen,
    required int index,
  }) {
    Color boxColor = isCompleted
        ? primaryGreen.withValues(alpha: 0.1)
        : (isLocked ? Colors.grey.shade200 : Colors.white);

    return Container(
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isLocked && !isCompleted)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
        border: Border.all(
          color: isCompleted
              ? primaryGreen.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isLocked) {
              HapticFeedback.vibrate();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Selesaikan materi sebelumnya terlebih dahulu!',
                  ),
                ),
              );
              return;
            }

            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MateriReadScreen(materi: materi, isCompleted: isCompleted),
              ),
            ).then((_) => _fetchModuleDetail());
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? primaryGreen
                        : (isLocked
                              ? Colors.grey.shade300
                              : Colors.blue.shade50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isLocked ? Icons.lock_rounded : _getMateriIcon(tipe),
                    color: isCompleted
                        ? Colors.white
                        : (isLocked
                              ? Colors.grey.shade500
                              : Colors.blue.shade700),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Materi $index',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isLocked
                              ? Colors.grey.shade500
                              : Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        materi['judul'] ?? 'Tanpa Judul',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isLocked
                              ? Colors.grey.shade500
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  )
                else if (!isLocked)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade400,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
