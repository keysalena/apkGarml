import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'module_detail_screen.dart';
import 'services/app_services.dart';
import 'ar_camera_screen.dart';
import 'theme/app_theme.dart';

class ModuleListScreen extends StatefulWidget {
  const ModuleListScreen({super.key});

  @override
  State<ModuleListScreen> createState() => _ModuleListScreenState();
}

class _ModuleListScreenState extends State<ModuleListScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  List<dynamic> _modules = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'Semua';
  static const List<String> _filters = [
    'Semua',
    'Belum mulai',
    'Berlangsung',
    'Selesai',
  ];

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
    _searchController.dispose();
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

  List<dynamic> _filteredModules() {
    final query = _searchController.text.trim().toLowerCase();
    return _modules.where((module) {
      final title = (module['judul'] ?? '').toString().toLowerCase();
      final matchesQuery = query.isEmpty || title.contains(query);
      final progress = (module['progress'] as num?)?.toDouble() ?? 0;
      final matchesFilter = switch (_selectedFilter) {
        'Belum mulai' => progress <= 0,
        'Berlangsung' => progress > 0 && progress < 1,
        'Selesai' => progress >= 1,
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final primaryGreen = Theme.of(context).primaryColor;
    final filteredModules = _filteredModules();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : RefreshIndicator(
              color: primaryGreen,
              onRefresh: () async {
                await _fetchModules(isManualRefresh: true);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: Stack(
                  children: [
                    SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primaryContainer,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.18,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.view_in_ar_rounded,
                                        size: 15,
                                        color: AppColors.mint,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'INTERAKTIF & 3D',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Katalog Modul',
                                    style: TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Eksplorasi materi dan gunakan Augmented Reality untuk memahami konsep lebih nyata.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Cari materi atau topik...',
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: _searchController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Hapus pencarian',
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 36,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              scrollDirection: Axis.horizontal,
                              itemCount: _filters.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final filter = _filters[index];
                                final selected = filter == _selectedFilter;
                                return ChoiceChip(
                                  label: Text(filter),
                                  selected: selected,
                                  showCheckmark: false,
                                  onSelected: (_) =>
                                      setState(() => _selectedFilter = filter),
                                  backgroundColor: Colors.white,
                                  selectedColor: primaryGreen.withValues(
                                    alpha: 0.12,
                                  ),
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? primaryGreen
                                        : Colors.grey.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  side: BorderSide(
                                    color: selected
                                        ? primaryGreen.withValues(alpha: 0.35)
                                        : Colors.grey.shade200,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (filteredModules.isEmpty)
                            Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _modules.isEmpty
                                      ? 'Belum ada modul tersedia.'
                                      : 'Modul tidak ditemukan. Coba kata kunci atau filter lain.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true, // Penting agar bisa masuk ke dalam SingleChildScrollView
                              physics: const NeverScrollableScrollPhysics(), // Scroll diambil alih oleh parent
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              itemCount: filteredModules.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final module = filteredModules[index];
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
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KOTAK NOMOR URUTAN
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? primaryGreen.withValues(alpha: 0.1)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
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
                            fontSize: 17,
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
                                  color: AppColors.mint.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  module['sub_cpmk'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
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
                                          : AppColors.tertiary,
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
                        color: AppColors.mint.withValues(alpha: 0.18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: InkWell(
                          // Tambahkan hitTestBehavior agar klik tidak tembus ke bawah
                          hoverColor: Colors.transparent,
                          splashColor: AppColors.mint.withValues(alpha: 0.3),
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
                                  color: AppColors.secondary,
                                  size: 22, // Ukuran ikon sedikit diperbesar
                                ),
                                const SizedBox(width: 6), // Jarak ikon dan teks
                                Text(
                                  'AR 3D',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
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
                color: isCompleted ? primaryGreen : AppColors.tertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
