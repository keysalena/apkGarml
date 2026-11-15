import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'module_detail_screen.dart';
import 'services/app_services.dart';
import 'ar_camera_screen.dart';

class ModuleListScreen extends StatefulWidget {
  const ModuleListScreen({super.key});

  @override
  State<ModuleListScreen> createState() => _ModuleListScreenState();
}

class _ModuleListScreenState extends State<ModuleListScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  List<dynamic> _modules = [];

  @override
  bool get wantKeepAlive => true;

  static const int _tabIndex = 1;
  static const String _cacheKey = 'cache_modules';

  bool _isFetching = false;
  DateTime? _lastFetch;

  @override
  void initState() {
    super.initState();
    AppSession.instance.dataVersion.addListener(_onDataChanged);
    AppSession.instance.tabIndex.addListener(_onTabChanged);
    _init();
  }

  @override
  void dispose() {
    AppSession.instance.dataVersion.removeListener(_onDataChanged);
    AppSession.instance.tabIndex.removeListener(_onTabChanged);
    super.dispose();
  }

  Future<void> _init() async {
    final cached = await LocalCache.load(_cacheKey);
    if (cached is List && mounted) {
      setState(() {
        _modules = cached;
        _isLoading = false;
      });
    }
    await _fetchModules();
  }

  void _onDataChanged() => _fetchModules();

  void _onTabChanged() {
    if (AppSession.instance.tabIndex.value != _tabIndex) return;
    final last = _lastFetch;
    if (last == null ||
        DateTime.now().difference(last) > const Duration(seconds: 30)) {
      _fetchModules();
    }
  }

  // Tambahkan parameter isManualRefresh
  Future<void> _fetchModules({bool isManualRefresh = false}) async {
    // Abaikan cegatan jika user menarik layar secara manual
    if (_isFetching && !isManualRefresh) return;

    _isFetching = true;
    try {
      final res = await ApiClient.get('/modules');
      if (!mounted) return;

      if (res.isSuccess && res.json['data'] is List) {
        final list = List<dynamic>.from(res.json['data']);
        setState(() {
          _modules = list;
          _isLoading = false;
        });
        _lastFetch = DateTime.now();
        LocalCache.save(_cacheKey, list);
      } else {
        if (_isLoading) setState(() => _isLoading = false);
        if (isManualRefresh && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memperbarui katalog.')),
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

  // Fungsi untuk membuka kamera AR
  void _openArCamera(BuildContext context, dynamic module) {
    // Mengekstrak URL AR dari data modul.
    // Sesuaikan pemanggilan key 'ar_content' dengan struktur JSON dari backend Anda.
    final List<dynamic> arContentList = module['ar_content'] ?? [];

    if (arContentList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konten AR belum tersedia untuk modul ini.'),
        ),
      );
      return;
    }

    // Mengambil item AR pertama dan URL Web AR-nya
    final arData = arContentList.first;
    final String arUrl = arData['model_3d_url'] ?? '';

    if (arUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link Web AR rusak atau kosong.')),
      );
      return;
    }

    // Buka halaman AR
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArCameraScreen(
          arUrl: arUrl,
          moduleTitle: module['judul'] ?? 'Modul',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final primaryGreen = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Latar belakang Off-White
      // KITA HAPUS APPBAR AGAR BISA MENGGUNAKAN HEADER OVERLAPPING
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : RefreshIndicator(
              color: primaryGreen,
              onRefresh: () async {
                await _fetchModules(isManualRefresh: true);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 120),
                child: Stack(
                  children: [
                    // ==========================================
                    // 1. HEADER HIJAU MELENGKUNG (KONSISTEN DENGAN HOME)
                    // ==========================================
                    Container(
                      height: 240, // Sedikit lebih tinggi untuk menampung teks deskripsi
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: primaryGreen,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(32),
                        ),
                      ),
                    ),

                    // ==========================================
                    // 2. KONTEN UTAMA
                    // ==========================================
                    SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- TEKS HEADER ---
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Katalog Modul',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Eksplorasi materi pembelajaran dan gunakan fitur Augmented Reality untuk pemahaman yang lebih nyata.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // --- DAFTAR KARTU MODUL OVERLAPPING ---
                          if (_modules.isEmpty)
                            Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Text('Belum ada modul tersedia.'),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true, // Penting agar bisa masuk ke dalam SingleChildScrollView
                              physics: const NeverScrollableScrollPhysics(), // Scroll diambil alih oleh parent
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              itemCount: _modules.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 20),
                              itemBuilder: (context, index) {
                                final module = _modules[index];
                                final double progressValue =
                                    (module['progress'] as num?)?.toDouble() ??
                                    0.0;
                                final bool isCompleted = progressValue >= 1.0;

                                return _buildModuleCard(
                                  context: context,
                                  module: module,
                                  progressValue: progressValue,
                                  isCompleted: isCompleted,
                                  primaryGreen: primaryGreen,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildModuleCard({
    required BuildContext context,
    required dynamic module,
    required double progressValue,
    required bool isCompleted,
    required Color primaryGreen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // --- BAGIAN ATAS: BISA DIKLIK UNTUK MASUK KE DETAIL MODUL ---
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ModuleDetailScreen(
                        moduleId: module['module_id']
                            .toString(), // <--- PERBAIKI BARIS INI
                        moduleTitle: module['judul'],
                      ),
                    ),
                  ).then((_) => _fetchModules());
                },
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KOTAK NOMOR URUTAN
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? primaryGreen.withValues(alpha: 0.1)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCompleted
                                ? primaryGreen.withValues(alpha: 0.3)
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Text(
                          '${module['urutan']}',
                          style: TextStyle(
                            color: isCompleted
                                ? primaryGreen
                                : Colors.grey.shade700,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // TEKS JUDUL & CHIP
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (module['sub_cpmk'] != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  module['sub_cpmk'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            Text(
                              module['judul'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text.rich(
                              TextSpan(
                                text: 'Progres materi: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                                children: [
                                  TextSpan(
                                    text: '${(progressValue * 100).toInt()}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isCompleted
                                          ? primaryGreen
                                          : Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // --- TOMBOL AR ---
                      // InkWell AR harus menangkap event kliknya sendiri
                      Material(
                        color: Colors.blue.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: InkWell(
                          // Tambahkan hitTestBehavior agar klik tidak tembus ke bawah
                          hoverColor: Colors.transparent,
                          splashColor: Colors.blue.shade100,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _openArCamera(context, module);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.view_in_ar_rounded,
                                  color: Colors.blue.shade700,
                                  size: 22, // Ukuran ikon sedikit diperbesar
                                ),
                                const SizedBox(width: 6), // Jarak ikon dan teks
                                Text(
                                  'AR 3D',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- INTEGRATED PROGRESS BAR DI BAWAH KARTU ---
            SizedBox(
              height: 4,
              width: double.infinity,
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: Colors.grey.shade100,
                color: isCompleted ? primaryGreen : Colors.orangeAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
