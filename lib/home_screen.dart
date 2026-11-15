import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'module_detail_screen.dart';
import 'services/app_services.dart';
import 'theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigate;

  const HomeScreen({super.key, this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  String _nama = 'Memuat...';
  int _level = 1;
  String? _avatarUrl;
  int _xp = 0;
  int _xpTarget = 500;
  int _modulSelesai = 0;
  int _totalModul = 0;
  String? _currentUserId;
  Map<String, dynamic>? _lastModule;

  // Variabel Leaderboard Baru
  List<dynamic> _leaderboardGlobal = [];
  List<dynamic> _leaderboardKelas = [];
  bool _isGlobalLeaderboard = false; // Default menampilkan peringkat kelas

  @override
  bool get wantKeepAlive => true;

  static const int _tabIndex = 0;
  static const String _cacheKey = 'cache_home';

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

  // Tampilkan data tersimpan lebih dulu (tanpa loading), lalu segarkan di belakang layar
  Future<void> _init() async {
    final cached = await LocalCache.load(_cacheKey);
    if (cached is Map && mounted) {
      setState(() {
        _applyData(Map<String, dynamic>.from(cached));
        _isLoading = false;
      });
    }
    await _fetchHomeData();
  }

  // XP / progres berubah -> refresh diam-diam
  void _onDataChanged() => _fetchHomeData();

  // Pindah ke tab ini -> refresh diam-diam hanya jika data sudah > 30 detik
  void _onTabChanged() {
    if (AppSession.instance.tabIndex.value != _tabIndex) return;
    final last = _lastFetch;
    if (last == null ||
        DateTime.now().difference(last) > const Duration(seconds: 30)) {
      _fetchHomeData();
    }
  }

  void _applyData(Map<String, dynamic> d) {
    final user = d['user'] ?? {};
    _nama = user['nama'] ?? 'Pengguna';
    _currentUserId = user['user_id']?.toString() ?? user['id']?.toString();
    _level = user['level'] ?? 1;
    _avatarUrl = user['avatar_url'];
    _xp = user['xp'] ?? 0;
    _xpTarget = user['xp_target'] ?? 500;

    _lastModule = d['last_module'];
    _modulSelesai = d['modul_selesai'] ?? 0;
    _totalModul = d['total_modul'] ?? 0;

    _leaderboardGlobal = d['leaderboard_global'] ?? [];
    _leaderboardKelas = d['leaderboard_kelas'] ?? [];
  }

  // Menambahkan parameter isManualRefresh untuk memaksa reload saat ditarik pengguna
  Future<void> _fetchHomeData({bool isManualRefresh = false}) async {
    // Abaikan cegatan jika ini adalah tarikan manual dari user
    if (_isFetching && !isManualRefresh) return;

    _isFetching = true;
    try {
      final res = await ApiClient.get('/home');
      if (!mounted) return;

      if (res.isSuccess && res.json['data'] is Map) {
        final d = Map<String, dynamic>.from(res.json['data']);
        setState(() {
          _applyData(d);
          _isLoading = false;
        });
        _lastFetch = DateTime.now();
        LocalCache.save(_cacheKey, d);
      } else {
        if (_isLoading) setState(() => _isLoading = false);
        // Beri tahu user jika gagal memuat saat ditarik
        if (isManualRefresh && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memperbarui data.')),
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final primaryGreen = Theme.of(context).primaryColor;

    // Tentukan data mana yang ditampilkan berdasarkan toggle aktif
    final activeLeaderboard = _isGlobalLeaderboard
        ? _leaderboardGlobal
        : _leaderboardKelas;
    final moduleProgress =
        (((_lastModule?['progress'] as num?)?.toDouble() ?? 0.0).clamp(
          0.0,
          1.0,
        )).toDouble();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : RefreshIndicator(
              color: primaryGreen,
              // Panggil dengan async/await dan paksa parameter manual refresh menjadi true
              onRefresh: () async {
                await _fetchHomeData(isManualRefresh: true);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: Stack(
                  children: [
                    SafeArea(
                      child: Column(
                        children: [
                          const SizedBox(height: 12),

                          // --- IDENTITAS PENGGUNA ---
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.mint.withValues(
                                    alpha: 0.3,
                                  ),
                                  backgroundImage:
                                      resolveAvatarUrl(_avatarUrl) != null
                                      ? NetworkImage(
                                          resolveAvatarUrl(_avatarUrl)!,
                                        )
                                      : null,
                                  child: resolveAvatarUrl(_avatarUrl) != null
                                      ? null
                                      : Text(
                                          initialOf(_nama),
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Halo, ${_nama.split(' ')[0]}! 👋',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Siap belajar hari ini?',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.xpBg,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.full,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.local_fire_department_rounded,
                                        color: AppColors.tertiaryContainer,
                                        size: 17,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Lv.$_level',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.tertiary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // --- KARTU LANJUTKAN BELAJAR ---
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.mint.withValues(alpha: 0.26),
                                    AppColors.surface,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.mint.withValues(
                                            alpha: 0.5,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.full,
                                          ),
                                        ),
                                        child: Text(
                                          _lastModule != null
                                              ? 'Modul ${_lastModule!['urutan']} Sedang Berjalan'
                                              : 'Mulai Belajar',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      // if (_lastModule != null)
                                      //   Text(
                                      //     '${(moduleProgress * 100).round()}%',
                                      //     style: const TextStyle(
                                      //       color: AppColors.textPrimary,
                                      //       fontSize: 11,
                                      //       fontWeight: FontWeight.bold,
                                      //     ),
                                      //   ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _lastModule != null
                                        ? _lastModule!['judul']
                                        : 'Pilih Modul Baru',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  if (_lastModule != null) ...[
                                    Builder(
                                      builder: (context) {
                                        return Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Progress',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                Text(
                                                  '${(moduleProgress * 100).round()}%',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: primaryGreen,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: LinearProgressIndicator(
                                                value: moduleProgress,
                                                backgroundColor:
                                                    Colors.grey.shade200,
                                                color: primaryGreen,
                                                minHeight: 8,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 24),
                                  ],

                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        if (_lastModule != null) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  ModuleDetailScreen(
                                                    moduleId:
                                                        _lastModule!['module_id']
                                                            .toString(),
                                                    moduleTitle:
                                                        _lastModule!['judul'],
                                                  ),
                                            ),
                                          ).then((_) => _fetchHomeData());
                                        } else {
                                          if (widget.onNavigate != null)
                                            widget.onNavigate!(1);
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryGreen,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.full,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        _lastModule != null
                                            ? 'Lanjutkan Materi'
                                            : 'Lihat Semua Modul',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // --- STATISTIK GAMIFIKASI 3 KOLOM ---
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: [
                                _buildStatCard(
                                  icon: Icons.stars_rounded,
                                  iconColor: AppColors.tertiaryContainer,
                                  title: 'Total XP',
                                  value: '$_xp',
                                  subtitle: '/$_xpTarget',
                                ),
                                const SizedBox(width: 12),
                                _buildStatCard(
                                  icon: Icons.menu_book_rounded,
                                  iconColor: AppColors.secondary,
                                  title: 'Modul',
                                  value: '$_modulSelesai',
                                  subtitle: '/$_totalModul',
                                ),
                                const SizedBox(width: 12),
                                _buildStatCard(
                                  icon: Icons.emoji_events_rounded,
                                  iconColor: AppColors.primary,
                                  title: 'Rank',
                                  value: 'Lv.$_level',
                                  subtitle: '',
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // --- LEADERBOARD & TOGGLE ---
                          if (_leaderboardGlobal.isNotEmpty ||
                              _leaderboardKelas.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Papan Peringkat',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  // Toggle Button Modern
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildToggleButton(
                                          title: 'Kelas',
                                          isGlobal: false,
                                          primaryGreen: primaryGreen,
                                        ),
                                        _buildToggleButton(
                                          title: 'Global',
                                          isGlobal: true,
                                          primaryGreen: primaryGreen,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Daftar Klasemen
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.03,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: activeLeaderboard.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.all(24.0),
                                        child: Center(
                                          child: Text(
                                            'Belum ada data peringkat.',
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        padding: const EdgeInsets.all(8),
                                        itemCount: activeLeaderboard.length,
                                        separatorBuilder: (context, index) =>
                                            Divider(
                                              height: 1,
                                              color: Colors.grey.shade100,
                                              indent: 76,
                                              endIndent: 16,
                                            ),
                                        itemBuilder: (context, index) {
                                          final user = activeLeaderboard[index];
                                          final rank = index + 1;
                                          final name =
                                              (user['nama'] ?? 'Pengguna')
                                                  .toString();
                                          final userId =
                                              user['user_id']?.toString() ??
                                              user['id']?.toString();
                                          final isCurrentUser =
                                              user['is_current_user'] == true ||
                                              (_currentUserId != null &&
                                                  userId == _currentUserId);

                                          Color rankColor = AppColors.textMuted;
                                          if (rank == 1) {
                                            rankColor =
                                                AppColors.tertiaryContainer;
                                          }
                                          if (rank == 2) {
                                            rankColor = const Color(0xFFBCCAC0);
                                          }
                                          if (rank == 3) {
                                            rankColor = AppColors.tertiary;
                                          }

                                          return Container(
                                            decoration: BoxDecoration(
                                              color: isCurrentUser
                                                  ? AppColors.mint.withValues(
                                                      alpha: 0.26,
                                                    )
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: ListTile(
                                              dense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              leading: SizedBox(
                                                width: 36,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (rank == 1)
                                                      const Text(
                                                        '👑',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          height: 1,
                                                        ),
                                                      ),
                                                    Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        color: rankColor
                                                            .withValues(
                                                              alpha: 0.15,
                                                            ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          '$rank',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: rankColor,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              title: Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                        color: AppColors
                                                            .textPrimary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isCurrentUser) ...[
                                                    const SizedBox(width: 5),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            AppColors.primary,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              AppRadius.full,
                                                            ),
                                                      ),
                                                      child: const Text(
                                                        'Kamu',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              subtitle: Text(
                                                'Level ${user['level'] ?? 1}',
                                                style: const TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    '${user['xp'] ?? 0}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          AppColors.textPrimary,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 3),
                                                  const Text(
                                                    'XP',
                                                    style: TextStyle(
                                                      color:
                                                          AppColors.textMuted,
                                                      fontSize: 9,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Komponen Toggle Button untuk Papan Peringkat
  Widget _buildToggleButton({
    required String title,
    required bool isGlobal,
    required Color primaryGreen,
  }) {
    final bool isActive = _isGlobalLeaderboard == isGlobal;
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          HapticFeedback.selectionClick();
          setState(() {
            _isGlobalLeaderboard = isGlobal;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
