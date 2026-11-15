import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk Haptic Feedback
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config/api_config.dart';
import 'services/app_services.dart';
import 'theme/app_theme.dart';

class MateriReadScreen extends StatefulWidget {
  final dynamic materi;
  final bool isCompleted; // status dari database (user_progress)

  const MateriReadScreen({
    super.key,
    required this.materi,
    this.isCompleted = false,
  });

  @override
  State<MateriReadScreen> createState() => _MateriReadScreenState();
}

class _MateriReadScreenState extends State<MateriReadScreen> {
  static const _accentHex = '#2E7D32'; // hijau, senada dengan panel admin

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _readProgress = ValueNotifier<double>(0);

  bool _isLoading = false;
  late bool _isCompleted;

  @override
  void initState() {
    super.initState();
    // Jika sudah selesai di database, tombol langsung disabled
    _isCompleted = widget.isCompleted;
    _scrollController.addListener(_updateReadProgress);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateReadProgress);
    _scrollController.dispose();
    _readProgress.dispose();
    super.dispose();
  }

  void _updateReadProgress() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) {
      _readProgress.value = 1;
      return;
    }
    _readProgress.value = (_scrollController.offset / max).clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // URL helper
  // ---------------------------------------------------------------------------

  /// Alamat situs (tanpa akhiran /api). Dipakai untuk mengubah path relatif
  /// seperti "/storage/materi_images/abc.png" menjadi URL lengkap.
  Uri get _siteBase {
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    return Uri.parse(base.endsWith('/') ? base : '$base/');
  }

  String _resolveUrl(String url) {
    if (url.startsWith('http')) return url;
    final path = url.startsWith('/') ? url.substring(1) : url;
    return _siteBase.resolve(path).toString();
  }

  Future<void> _bukaUrl() async {
    final raw = widget.materi['konten_url']?.toString();
    if (raw == null || raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tautan materi belum tersedia.')),
      );
      return;
    }
    final ok = await launchUrl(
      Uri.parse(_resolveUrl(raw)),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka tautan.')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Konten HTML (dari CKEditor)
  // ---------------------------------------------------------------------------

  /// Gaya tambahan agar hasil CKEditor (tabel, kutipan, ukuran font, gambar)
  /// tampil rapi di layar ponsel.
  Map<String, String>? _htmlStyles(dynamic element) {
    final String tag = element.localName ?? '';
    final classes = element.classes;

    // Ukuran font bawaan CKEditor 5 memakai class, bukan inline style
    if (classes.contains('text-tiny')) return {'font-size': '0.7em'};
    if (classes.contains('text-small')) return {'font-size': '0.85em'};
    if (classes.contains('text-big')) return {'font-size': '1.4em'};
    if (classes.contains('text-huge')) return {'font-size': '1.8em'};

    switch (tag) {
      case 'figure':
        return {'margin': '16px 0'};
      case 'figcaption':
        return {
          'font-size': '13px',
          'color': '#757575',
          'text-align': 'center',
          'margin-top': '6px',
        };
      case 'img':
        return {'margin': '4px 0'};
      case 'h1':
      case 'h2':
        return {
          'font-weight': 'bold',
          'margin': '28px 0 10px 0',
          'color': '#1B1B1B',
        };
      case 'h3':
      case 'h4':
        return {
          'font-weight': 'bold',
          'margin': '22px 0 8px 0',
          'color': '#2B2B2B',
        };
      case 'p':
        return {'margin': '0 0 14px 0'};
      case 'ul':
      case 'ol':
        return {'margin': '0 0 14px 0'};
      case 'li':
        return {'margin': '0 0 6px 0'};
      case 'blockquote':
        return {
          'border-left': '4px solid $_accentHex',
          'background-color': '#F3F8F3',
          'padding': '10px 14px',
          'margin': '16px 0',
          'color': '#424242',
          'font-style': 'italic',
        };
      case 'table':
        return {'border-collapse': 'collapse', 'width': '100%'};
      case 'th':
        return {
          'border': '1px solid #D5DBD5',
          'padding': '8px 10px',
          'background-color': '#EEF4EE',
          'font-weight': 'bold',
        };
      case 'td':
        return {'border': '1px solid #E0E4E0', 'padding': '8px 10px'};
      case 'hr':
        return {'margin': '24px 0'};
      case 'a':
        return {'color': _accentHex};
    }
    return null;
  }

  void _showImageViewer(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHtmlContent(String html) {
    return HtmlWidget(
      html,
      // KUNCI agar gambar muncul: ubah path relatif (/storage/...) menjadi
      // URL lengkap berdasarkan alamat server.
      baseUrl: _siteBase,
      textStyle: TextStyle(
        fontSize: 16,
        color: Colors.black.withValues(alpha: 0.82),
        height: 1.75,
      ),
      customStylesBuilder: _htmlStyles,
      onTapImage: (image) {
        if (image.sources.isEmpty) return;
        _showImageViewer(image.sources.first.url);
      },
      onTapUrl: (url) async {
        final uri = Uri.tryParse(_resolveUrl(url));
        if (uri == null) return false;
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      onLoadingBuilder: (context, element, loadingProgress) => Container(
        height: 160,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      onErrorBuilder: (context, element, error) => Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: Colors.grey.shade500),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Gambar tidak dapat dimuat',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Perkiraan waktu baca (200 kata/menit) dari konten HTML.
  int _estimateReadMinutes(String html) {
    final text = html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .trim();
    if (text.isEmpty) return 1;
    final words = text.split(RegExp(r'\s+')).length;
    final minutes = (words / 200).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  // ---------------------------------------------------------------------------
  // Selesaikan materi
  // ---------------------------------------------------------------------------

  Future<void> _selesaikanMateri() async {
    if (_isCompleted) return;

    setState(() => _isLoading = true);

    try {
      final materiId = widget.materi['materi_id'].toString();
      final res = await ApiClient.post('/materi/$materiId/complete');

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = res.json;
        if (data is Map && data['success'] == true) {
          final result = data['data'] ?? {};
          // Home / Modul / Profil refresh diam-diam (XP & progres berubah)
          AppSession.instance.notifyDataChanged();
          final int xp = result['xp_gained'] ?? 0;

          setState(() {
            _isCompleted = true;
            _isLoading = false;
          });

          // xp = 0 berarti materi sudah pernah diselesaikan sebelumnya
          if (xp == 0) return;

          HapticFeedback.heavyImpact();
          _showRewardBottomSheet(
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
          content: Text('Gagal menyimpan progres. Silakan coba lagi.'),
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

  // UI Modal Bottom Sheet bergaya modern (Glass/Rounded)
  void _showRewardBottomSheet({
    required int xpGained,
    required bool isLevelUp,
    required int newLevel,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
                      ? AppColors.xpBg
                      : AppColors.mint.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLevelUp ? Icons.emoji_events_rounded : Icons.stars_rounded,
                  size: 64,
                  color: isLevelUp ? AppColors.tertiary : AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isLevelUp ? 'Level Up!' : 'Luar Biasa!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isLevelUp
                    ? 'Selamat! Kamu telah mencapai Level $newLevel.\n+$xpGained XP berhasil didapatkan.'
                    : 'Kamu berhasil menyelesaikan materi ini dan mendapatkan +$xpGained XP.',
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
                    Navigator.pop(context); // Tutup modal
                    Navigator.pop(context); // Kembali ke daftar materi
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
                    'Lanjutkan Belajar',
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final primaryGreen = Theme.of(context).primaryColor;
    final String tipe =
        widget.materi['tipe']?.toString().toLowerCase() ?? 'teks';

    // 'pendahuluan' juga berisi HTML, sama seperti 'teks'
    final bool isHtml = tipe == 'teks' || tipe == 'pendahuluan';
    final String html = (widget.materi['konten_teks'] ?? '').toString().trim();
    final String kontenHtml = html.isEmpty ? '<p>Tidak ada konten.</p>' : html;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        // Bar progres membaca di bawah AppBar
        bottom: isHtml
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: ValueListenableBuilder<double>(
                  valueListenable: _readProgress,
                  builder: (_, value, __) => LinearProgressIndicator(
                    value: value,
                    minHeight: 3,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          // ==========================================
          // 1. AREA KONTEN (Teks, Video, atau PDF)
          // ==========================================
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetaRow(tipe, isHtml ? kontenHtml : null),
                  const SizedBox(height: 14),

                  // Judul Materi
                  Text(
                    widget.materi['judul'] ?? 'Tanpa Judul',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      height: 1.25,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade200, height: 1),
                  const SizedBox(height: 20),

                  if (isHtml)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: _buildHtmlContent(kontenHtml),
                    )
                  else
                    _buildMediaCard(tipe, primaryGreen),
                ],
              ),
            ),
          ),

          // ==========================================
          // 2. STICKY BOTTOM BUTTON (Dipaku di bawah)
          // ==========================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: ElevatedButton(
                onPressed: _isCompleted || _isLoading
                    ? null
                    : _selesaikanMateri,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCompleted
                      ? Colors.grey.shade200
                      : primaryGreen,
                  foregroundColor: _isCompleted
                      ? Colors.grey.shade600
                      : Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  disabledForegroundColor: Colors.grey.shade500,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isCompleted
                                ? Icons.check_circle_rounded
                                : Icons.star_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isCompleted
                                ? 'Materi Selesai'
                                : 'Selesai & Dapatkan XP',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Baris label tipe + waktu baca
  Widget _buildMetaRow(String tipe, String? htmlForEstimate) {
    final IconData icon;
    final String label;
    switch (tipe) {
      case 'video':
        icon = Icons.play_circle_outline_rounded;
        label = 'VIDEO';
        break;
      case 'pdf':
        icon = Icons.picture_as_pdf_outlined;
        label = 'DOKUMEN PDF';
        break;
      case 'pendahuluan':
        icon = Icons.flag_outlined;
        label = 'PENDAHULUAN';
        break;
      default:
        icon = Icons.menu_book_outlined;
        label = 'BACAAN';
    }

    Widget chip(IconData i, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(icon, label),
        // if (htmlForEstimate != null)
        //   chip(
        //     Icons.schedule_rounded,
        //     '${_estimateReadMinutes(htmlForEstimate)} menit baca',
        //   ),
      ],
    );
  }

  // Desain Kartu Raksasa untuk Materi Video atau PDF
  Widget _buildMediaCard(String tipe, Color primaryGreen) {
    final isVideo = tipe == 'video';
    final Color cardColor = isVideo
        ? AppColors.mint.withValues(alpha: 0.18)
        : AppColors.xpBg.withValues(alpha: 0.6);
    final Color iconColor = isVideo
        ? AppColors.primaryContainer
        : AppColors.tertiaryContainer;
    final IconData iconData = isVideo
        ? Icons.play_circle_fill_rounded
        : Icons.picture_as_pdf_rounded;
    final String actionText = isVideo
        ? 'Tonton Video Penuh'
        : 'Buka Dokumen PDF';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(iconData, size: 80, color: iconColor),
          const SizedBox(height: 24),
          Text(
            isVideo
                ? 'Materi Pembelajaran Interaktif'
                : 'Dokumen Bacaan Pendukung',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isVideo ? AppColors.primary : AppColors.tertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tekan tombol di bawah untuk membuka materi ini di aplikasi eksternal.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isVideo ? AppColors.secondary : AppColors.tertiary,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              _bukaUrl();
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(
              actionText,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: iconColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
