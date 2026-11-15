import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'help_center_screen.dart';
import 'services/app_services.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  String _nama = 'Memuat...';
  String _email = 'Memuat...';
  String? _avatarUrl;
  String _bergabungSejak = '-';
  String _kelas = 'Belum ada kelas'; // <-- Variabel untuk menyimpan data kelas

  @override
  bool get wantKeepAlive => true;

  static const int _tabIndex = 2;
  static const String _cacheKey = 'cache_profile';

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

  // Tampilkan data tersimpan dulu (tanpa loading), lalu segarkan di belakang layar
  Future<void> _init() async {
    final cached = await LocalCache.load(_cacheKey);
    if (cached is Map && mounted) {
      setState(() {
        _applyData(Map<String, dynamic>.from(cached));
        _isLoading = false;
      });
    }
    await _fetchProfileData();
  }

  // Profil / avatar berubah -> refresh diam-diam
  void _onDataChanged() => _fetchProfileData();

  void _onTabChanged() {
    if (AppSession.instance.tabIndex.value != _tabIndex) return;
    final last = _lastFetch;
    if (last == null ||
        DateTime.now().difference(last) > const Duration(seconds: 30)) {
      _fetchProfileData();
    }
  }

  void _applyData(Map<String, dynamic> p) {
    _nama = p['nama'] ?? p['name'] ?? 'Pengguna';
    _email = p['email'] ?? 'Tidak ada email';
    _avatarUrl = p['avatar_url'];
    _kelas = p['nama_kelas'] ?? 'Belum ada kelas';
    final rawDate = p['bergabung_sejak'] ?? p['created_at'];
    _bergabungSejak = _formatTanggalIndo(rawDate?.toString());
  }

  // --- FUNGSI FORMAT TANGGAL BAHASA INDONESIA ---
  String _formatTanggalIndo(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '-';
    try {
      final DateTime parsedDate = DateTime.parse(dateString);
      // Format 25 Oktober 2026. 'id' bisa digunakan jika locale disetel,
      // tetapi untuk amannya kita bisa mapping manual bulannya atau pakai pattern:

      final List<String> bulan = [
        '',
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];

      String day = parsedDate.day.toString();
      String monthName = bulan[parsedDate.month];
      String year = parsedDate.year.toString();

      return '$day $monthName $year';
    } catch (e) {
      // Jika parsing gagal, kembalikan teks aslinya
      return dateString;
    }
  }

  // Tambahkan parameter isManualRefresh
  Future<void> _fetchProfileData({bool isManualRefresh = false}) async {
    // Abaikan cegatan jika user menarik layar secara manual
    if (_isFetching && !isManualRefresh) return;

    _isFetching = true;
    try {
      final res = await ApiClient.get('/user/profile');
      if (!mounted) return;

      if (res.isSuccess && res.json['data'] is Map) {
        final p = Map<String, dynamic>.from(res.json['data']);
        setState(() {
          _applyData(p);
          _isLoading = false;
        });
        _lastFetch = DateTime.now();
        LocalCache.save(_cacheKey, p);
      } else {
        if (_isLoading) setState(() => _isLoading = false);
        // Tampilkan pesan jika refresh manual gagal
        if (isManualRefresh && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memperbarui profil.')),
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

  Future<void> _forceLogout() =>
      AppSession.instance.forceLogout(revokeOnServer: true);

  void _showLogoutDialog() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Keluar Akun',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Apakah kamu yakin ingin keluar dari sesi belajarmu saat ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _forceLogout();
            },
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final primaryGreen = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : RefreshIndicator(
              color: primaryGreen,
              onRefresh: () async {
                await _fetchProfileData(isManualRefresh: true);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 120),
                child: Stack(
                  children: [
                    Container(
                      height: 240,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: primaryGreen,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(32),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(24, 20, 24, 20),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Profil Saya',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
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
                              child: Column(
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.grey.shade100,
                                            width: 2,
                                          ),
                                        ),
                                        child: CircleAvatar(
                                          radius: 46,
                                          backgroundColor: Colors.grey.shade200,
                                          backgroundImage:
                                              resolveAvatarUrl(_avatarUrl) !=
                                                  null
                                              ? NetworkImage(
                                                  resolveAvatarUrl(_avatarUrl)!,
                                                )
                                              : null,
                                          child:
                                              resolveAvatarUrl(_avatarUrl) !=
                                                  null
                                              ? null
                                              : Text(
                                                  initialOf(_nama),
                                                  style: TextStyle(
                                                    color: Colors.black54,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 22,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  EditProfileScreen(
                                                    currentNama: _nama,
                                                    currentEmail: _email,
                                                    currentAvatar: _avatarUrl,
                                                  ),
                                            ),
                                          ).then((isUpdated) {
                                            if (isUpdated == true) {
                                              _fetchProfileData();
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: primaryGreen,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.edit_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    _nama,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _email,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // --- BADGE KELAS & TANGGAL GABUNG ---
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.orange.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.school_rounded,
                                              size: 14,
                                              color: Colors.orange.shade700,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _kelas,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Bergabung sejak $_bergabungSejak',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),

                                  // -------------------------------------
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PENGATURAN UMUM',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.04,
                                        ),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      _buildMenuTile(
                                        icon: Icons.person_outline_rounded,
                                        iconColor: Colors.blue,
                                        title: 'Edit Profil',
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  EditProfileScreen(
                                                    currentNama: _nama,
                                                    currentEmail: _email,
                                                    currentAvatar: _avatarUrl,
                                                  ),
                                            ),
                                          ).then((isUpdated) {
                                            if (isUpdated == true) {
                                              _fetchProfileData();
                                            }
                                          });
                                        },
                                      ),
                                      _buildDivider(),
                                      _buildMenuTile(
                                        icon: Icons.lock_outline_rounded,
                                        iconColor: Colors.orange,
                                        title: 'Ubah Kata Sandi',
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const ChangePasswordScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                      _buildDivider(),
                                      _buildMenuTile(
                                        icon: Icons.help_outline_rounded,
                                        iconColor: primaryGreen,
                                        title: 'Pusat Bantuan',
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const HelpCenterScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 24),

                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.04,
                                        ),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: _buildMenuTile(
                                    icon: Icons.logout_rounded,
                                    iconColor: Colors.red,
                                    title: 'Keluar Akun',
                                    textColor: Colors.red,
                                    hideArrow: true,
                                    onTap: _showLogoutDialog,
                                  ),
                                ),
                              ],
                            ),
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

  Widget _buildMenuTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
    Color textColor = Colors.black87,
    bool hideArrow = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              if (!hideArrow)
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 64, right: 20),
      child: Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
    );
  }
}
