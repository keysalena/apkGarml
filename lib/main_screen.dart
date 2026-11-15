import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Diperlukan untuk Haptic Feedback

import 'home_screen.dart';
import 'module_list_screen.dart';
import 'profile_screen.dart';
import 'services/app_services.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Tab dibangun lazy saat pertama dibuka, lalu DIPERTAHANKAN (IndexedStack)
  // sehingga tidak load ulang & tampilan sebelumnya tetap tersimpan.
  final List<bool> _visited = [true, false, false];

  late final List<Widget> _pages = [
    HomeScreen(onNavigate: _onNavigate),
    const ModuleListScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    AppSession.instance.tabIndex.value = 0;
  }

  // Fungsi untuk berpindah tab, bisa dipanggil dari halaman lain (seperti HomeScreen)
  void _onNavigate(int index) {
    if (index == _selectedIndex) return;

    // Memberikan efek getaran 'tik' yang halus ala aplikasi premium modern
    HapticFeedback.selectionClick();

    setState(() {
      _selectedIndex = index;
      _visited[index] = true;
    });
    // Tab yang dibuka akan refresh diam-diam jika datanya sudah lama
    AppSession.instance.tabIndex.value = index;
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = Theme.of(context).primaryColor;

    return Scaffold(
      // Warna Off-White agar mata tidak lelah (lebih baik dari Colors.white murni)
      backgroundColor: const Color(0xFFF8F9FA), 
      
      // IndexedStack: state tiap tab tetap hidup saat berpindah tab
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(
          _pages.length,
          (i) => _visited[i] ? _pages[i] : const SizedBox.shrink(),
        ),
      ),
      
      // extendBody membuat background halaman memanjang ke bawah area nav bar yang melayang
      extendBody: true, 
      
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 20), // Margin agar melayang
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32), // Bentuk Pill (kapsul)
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06), // Soft shadow luas
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0, 
                activeIcon: Icons.space_dashboard_rounded, 
                inactiveIcon: Icons.space_dashboard_outlined, 
                label: 'Beranda', 
                color: primaryGreen,
              ),
              _buildNavItem(
                index: 1, 
                activeIcon: Icons.menu_book_rounded, 
                inactiveIcon: Icons.book_outlined, 
                label: 'Modul', 
                color: primaryGreen,
              ),
              _buildNavItem(
                index: 2, 
                activeIcon: Icons.person_rounded, 
                inactiveIcon: Icons.person_outline_rounded, 
                label: 'Profil', 
                color: primaryGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget custom untuk tombol navigasi yang bisa melebar otomatis saat aktif
  Widget _buildNavItem({
    required int index, 
    required IconData activeIcon, 
    required IconData inactiveIcon, 
    required String label, 
    required Color color
  }) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onNavigate(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          // Latar belakang transparan jika tidak aktif, hijau pudar jika aktif
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? color : Colors.grey.shade400,
              size: 26,
            ),
            // Teks hanya muncul jika tab sedang aktif (Dynamic Pill Animation)
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}