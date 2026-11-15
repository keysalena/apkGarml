
import 'package:flutter/material.dart';

import '../main_screen.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _selectedKelasId;
  List<dynamic> _kelasList = [];

  bool _isLoading = false;
  bool _isLoadingKelas = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _fetchKelas(); // Ambil daftar kelas saat halaman dimuat
  }

  Future<void> _fetchKelas() async {
    try {
      final res = await ApiClient.get('/kelas', auth: false);
      if (res.statusCode == 200) {
        final data = res.json;
        if (data is Map && data['success'] == true && mounted) {
          setState(() {
            _kelasList = data['data'];
          });
        }
      }
    } catch (e) {
      // Error jaringan akan ditangkap di sini
    } finally {
      // Pastikan loading selalu berhenti baik saat sukses maupun gagal
      if (mounted) {
        setState(() => _isLoadingKelas = false);
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // Validasi double check di sisi Flutter[cite: 15]
    final email = _emailController.text.trim();
    if (!email.endsWith('@um.ac.id') && !email.endsWith('@student.um.ac.id')) {
      showAppSnackBar(
        context,
        'Wajib menggunakan email um.ac.id',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await ApiClient.post(
        '/register',
        auth: false,
        body: {
          'nama': _namaController.text.trim(),
          'email': email,
          'password': _passwordController.text,
          'kelas_id': _selectedKelasId,
        },
      );
      if (res.statusCode == 0) throw Exception('network');

      final data = res.json is Map ? res.json as Map : {};

      if (res.statusCode == 201 && data['success'] == true) {
        await LocalCache.clearAll();
        final prefs = await appPrefs();
        await prefs.setString('auth_token', data['data']['token']);

        if (mounted) {
          showAppSnackBar(context, 'Registrasi Berhasil!');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          showAppSnackBar(
            context,
            data['message'] ??
                'Registrasi gagal. Email mungkin sudah terdaftar.',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Tidak dapat terhubung ke server. Periksa koneksi Anda.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Buat Akun Baru',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Daftar untuk memulai pembelajaran',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),

                      TextFormField(
                        controller: _namaController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Lengkap',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Nama wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email (Wajib @um.ac.id)',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Email wajib diisi';
                          if (!value.endsWith('@um.ac.id') &&
                              !value.endsWith('@student.um.ac.id')) {
                            return 'Gunakan email kampus (um.ac.id)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _isLoadingKelas
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<String>(
                              value: _selectedKelasId,
                              isExpanded: true,
                              // 1. Kustomisasi Ikon Dropdown agar lebih modern
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.grey,
                              ),

                              // 2. Kustomisasi Menu Pop-up (Kotak daftar pilihan)
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              elevation: 4,
                              menuMaxHeight: 300, // Batasi tinggi menu agar tidak menutupi seluruh layar
                              // 3. Kustomisasi Kotak Input (Disamakan dengan TextFormField)
                              decoration: InputDecoration(
                                labelText: 'Pilih Kelas',
                                prefixIcon: const Icon(Icons.class_outlined),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).primaryColor,
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.red,
                                  ),
                                ),
                              ),

                              // 4. Kustomisasi Teks Item
                              items: _isLoadingKelas
                                  ? [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text(
                                          'Memuat daftar kelas...',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontStyle: FontStyle.italic,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ]
                                  : _kelasList.map((kelas) {
                                      final nama = kelas['nama_kelas'] ?? '';
                                      final tahun = kelas['tahun_ajaran'] ?? '';
                                      final labelTampil = tahun.isNotEmpty
                                          ? '$nama ($tahun)'
                                          : nama;

                                      return DropdownMenuItem<String>(
                                        value: kelas['kelas_id'].toString(),
                                        child: Text(
                                          labelTampil,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              onChanged: _isLoadingKelas
                                  ? null
                                  : (val) {
                                      setState(() {
                                        _selectedKelasId = val;
                                      });
                                    },
                              validator: (value) =>
                                  value == null ? 'Pilih kelas Anda' : null,
                            ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Password wajib diisi';
                          if (value.length < 6) return 'Minimal 6 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            )
                          : ElevatedButton(
                              onPressed: _register,
                              child: const Text('Daftar Sekarang'),
                            ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Sudah punya akun? ',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          InkWell(
                            onTap: () {
                              // Menggunakan pop karena halaman login sudah ada di tumpukan (stack) navigasi sebelumnya
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Masuk',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
