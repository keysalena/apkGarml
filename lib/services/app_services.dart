import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/login_screen.dart';
import '../config/api_config.dart';

/// Navigator global supaya logout bisa dilakukan dari mana saja (tanpa context).
/// WAJIB dipasang di MaterialApp(navigatorKey: appNavigatorKey) -> lihat main.dart.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

const String _tokenKey = 'auth_token';
const String _cachePrefix = 'cache_';

/// SharedPreferences dibuka SEKALI lalu dipakai ulang (dipanggil dari main()).
SharedPreferences? _prefsInstance;
Future<SharedPreferences> appPrefs() async =>
    _prefsInstance ??= await SharedPreferences.getInstance();

/// Mengubah path avatar dari backend menjadi URL lengkap.
/// Mendukung dua bentuk: path mentah ("avatars/x.jpg") ATAU URL penuh.
String? resolveAvatarUrl(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  final root = ApiConfig.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
  return '$root/storage/$raw';
}

/// Huruf pertama nama untuk avatar bawaan (digambar lokal, tanpa request internet).
String initialOf(String name) {
  final t = name.trim();
  return t.isEmpty ? '?' : t.characters.first.toUpperCase();
}

/// State global ringan: penanda "data berubah" dan tab yang sedang aktif.
class AppSession {
  AppSession._();
  static final AppSession instance = AppSession._();

  /// Naik setiap kali ada perubahan data (XP, materi selesai, profil, avatar).
  /// Home / Modul / Profil mendengarkan ini lalu refresh diam-diam.
  final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);

  /// Tab aktif di MainScreen.
  final ValueNotifier<int> tabIndex = ValueNotifier<int>(0);

  void notifyDataChanged() => dataVersion.value++;

  bool _loggingOut = false;

  /// Logout paksa. Aman dipanggil berkali-kali.
  /// [revokeOnServer] = true untuk logout manual: token ikut dicabut di server.
  Future<void> forceLogout({bool revokeOnServer = false}) async {
    if (_loggingOut) return;
    _loggingOut = true;
    try {
      final prefs = await appPrefs();
      final token = prefs.getString(_tokenKey);

      if (revokeOnServer && token != null && token.isNotEmpty) {
        // Best effort, tidak ditunggu: logout di layar tidak boleh terhambat jaringan.
        ApiClient.revokeToken(token);
      }

      await prefs.remove(_tokenKey);
      await prefs.remove('completed_materi');
      await LocalCache.clearAll();
      tabIndex.value = 0;

      appNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } finally {
      // Jeda singkat agar request lain yang masih berjalan tidak memicu logout ganda.
      Future.delayed(const Duration(seconds: 2), () => _loggingOut = false);
    }
  }
}

/// Cache JSON sederhana di SharedPreferences. Semua key berawalan "cache_"
/// sehingga bisa dihapus sekaligus saat logout (termasuk cache per-modul).
class LocalCache {
  static Future<void> save(String key, dynamic data) async {
    try {
      final prefs = await appPrefs();
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {}
  }

  static Future<dynamic> load(String key) async {
    try {
      final prefs = await appPrefs();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearAll() async {
    try {
      final prefs = await appPrefs();
      for (final k in prefs.getKeys().toList()) {
        if (k.startsWith(_cachePrefix)) await prefs.remove(k);
      }
    } catch (_) {}
  }
}

class ApiResult {
  final int statusCode; // 0 = gagal jaringan / timeout
  final dynamic json;
  const ApiResult(this.statusCode, this.json);

  bool get isSuccess =>
      (statusCode == 200 || statusCode == 201) &&
      json is Map &&
      (json as Map)['success'] == true;

  /// Pesan dari backend (mis. validasi) jika ada.
  String? get message => json is Map ? (json as Map)['message']?.toString() : null;
}

dynamic _parseJson(String s) {
  try {
    return jsonDecode(s);
  } catch (_) {
    return null;
  }
}

/// Satu pintu untuk semua request ke API.
///  - 1 http.Client dipakai ulang: koneksi + TLS tidak dibuat ulang tiap request.
///  - Timeout 20 detik, tidak ada spinner yang menggantung selamanya.
///  - JSON besar di-decode di isolate lain agar UI tidak patah-patah.
///  - Aturan logout (hanya untuk request ber-token):
///      * 401 dicoba ulang sekali; logout hanya jika 401 dua kali DAN token
///        di perangkat masih token yang sama.
///      * Error jaringan / 5xx / respons aneh TIDAK pernah menyebabkan logout.
class ApiClient {
  ApiClient._();

  static final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 20);

  /// Panggil sekali di main() agar request pertama tidak menunggu disk.
  static Future<void> init() async {
    await appPrefs();
  }

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  static Future<ApiResult> get(String path, {bool auth = true}) {
    return _execute(
      (h) => _client.get(_uri(path), headers: h),
      auth: auth,
      retryOnNetworkError: true, // GET aman diulang
    );
  }

  static Future<ApiResult> post(String path, {Object? body, bool auth = true}) {
    return _execute(
      (h) => _client.post(
        _uri(path),
        headers: {...h, 'Content-Type': 'application/json'},
        body: body == null ? null : jsonEncode(body),
      ),
      auth: auth,
    );
  }

  /// Upload 1 file (multipart). Request dibuat ulang tiap percobaan.
  static Future<ApiResult> postFile(String path, String field, String filePath) {
    return _execute((h) async {
      final req = http.MultipartRequest('POST', _uri(path))
        ..headers.addAll(h)
        ..files.add(await http.MultipartFile.fromPath(field, filePath));
      return http.Response.fromStream(await _client.send(req));
    });
  }

  /// Cabut token di server (logout manual). Tidak melempar error.
  static void revokeToken(String token) {
    _client
        .post(
          _uri('/logout'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 5))
        .then((_) {}, onError: (_) {});
  }

  static Future<dynamic> _decode(String body) async {
    if (body.isEmpty) return null;
    if (body.length > 16000) return compute(_parseJson, body);
    return _parseJson(body);
  }

  static Future<ApiResult> _execute(
    Future<http.Response> Function(Map<String, String> headers) call, {
    bool auth = true,
    bool retryOnNetworkError = false,
  }) async {
    String? usedToken;
    if (auth) {
      final prefs = await appPrefs();
      usedToken = prefs.getString(_tokenKey);
      if (usedToken == null || usedToken.isEmpty) {
        await AppSession.instance.forceLogout();
        return const ApiResult(401, null);
      }
    }

    const maxAttempts = 2;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await call({
          'Accept': 'application/json',
          if (usedToken != null) 'Authorization': 'Bearer $usedToken',
        }).timeout(_timeout);

        if (auth && response.statusCode == 401) {
          if (attempt == 0) {
            await Future.delayed(const Duration(milliseconds: 300));
            continue;
          }
          final current = (await appPrefs()).getString(_tokenKey);
          if (current == usedToken) {
            await AppSession.instance.forceLogout();
          }
          return const ApiResult(401, null);
        }

        return ApiResult(response.statusCode, await _decode(response.body));
      } catch (_) {
        if (!retryOnNetworkError || attempt == maxAttempts - 1) {
          return const ApiResult(0, null);
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return const ApiResult(0, null);
  }
}
