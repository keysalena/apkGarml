import 'dart:io'; // Untuk File

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Untuk ambil dari galeri

import 'services/app_services.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentNama;
  final String currentEmail;
  final String? currentAvatar;

  const EditProfileScreen({
    super.key,
    required this.currentNama,
    required this.currentEmail,
    this.currentAvatar,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaController;
  late TextEditingController _emailController;

  bool _isLoading = false;
  bool _isUploadingAvatar = false;

  String? _avatarUrl;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.currentNama);
    _emailController = TextEditingController(text: widget.currentEmail);
    _avatarUrl = widget.currentAvatar;
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Fungsi untuk memilih gambar dari galeri dan langsung mengunggahnya
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _isUploadingAvatar = true;
      });

      try {
        final res = await ApiClient.postFile(
          '/user/profile/avatar',
          'avatar',
          _imageFile!.path,
        );

        if (res.statusCode == 200 && res.json is Map) {
          final data = res.json as Map;
          setState(() {
            _avatarUrl = data['avatar_url']?.toString();
          });
          AppSession.instance.notifyDataChanged();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Foto profil berhasil diubah!')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gagal mengunggah foto profil.')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Terjadi kesalahan jaringan.')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final res = await ApiClient.post(
        '/user/profile/update',
        body: {
          'nama': _namaController.text.trim(),
          'email': _emailController.text.trim(),
        },
      );

      if (!mounted) return;
      if (res.statusCode == 0) throw Exception('network');

      if (res.statusCode == 200) {
        final data = res.json;
        if (data is Map && data['success'] == true) {
          AppSession.instance.notifyDataChanged();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil berhasil diperbarui!')),
          );
          Navigator.pop(context, true);
          return;
        }
      }

      final errorData = res.json is Map ? res.json as Map : {};
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorData['message'] ?? 'Gagal memperbarui profil'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan jaringan.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Edit Profil',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar Preview dengan tombol edit
              Center(
                child: GestureDetector(
                  onTap: _isUploadingAvatar ? null : _pickAndUploadImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!) as ImageProvider
                              : NetworkImage(
                                  (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                      ? resolveAvatarUrl(_avatarUrl)!
                                      : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_namaController.text)}&background=random&size=200',
                                ),
                          child: _isUploadingAvatar
                              ? Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              TextFormField(
                controller: _namaController,
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: primaryGreen, width: 2),
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Nama tidak boleh kosong' : null,
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: primaryGreen, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Email wajib diisi';
                  if (!value.endsWith('@um.ac.id') &&
                      !value.endsWith('@student.um.ac.id'))
                    return 'Gunakan email kampus (um.ac.id)';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: primaryGreen),
                    )
                  : ElevatedButton(
                      onPressed: _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Simpan Perubahan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
