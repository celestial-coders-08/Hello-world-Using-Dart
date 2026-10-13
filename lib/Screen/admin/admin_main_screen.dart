import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/login.dart';
import 'admin_theme.dart';
import 'admin_user_dashboard.dart';
import 'admin_seller_dashboard.dart';
import 'admin_sales_dashboard.dart';

class AdminMainScreen extends StatefulWidget {
  final String adminEmail;

  const AdminMainScreen({
    super.key,
    this.adminEmail = 'admin@pawstay.com',
  });

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    AdminUserDashboard(),
    AdminSellerDashboard(),
    AdminSalesDashboard(),
  ];

  final List<String> _titles = [
    'User Management',
    'Seller & Providers',
    'Sales & Analytics',
  ];

  void _showSystemHealthModal() {
    showDialog(
      context: context,
      builder: (ctx) => ValueListenableBuilder<bool>(
        valueListenable: AdminTheme.isDarkMode,
        builder: (context, isDark, _) => AlertDialog(
          backgroundColor: AdminTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AdminTheme.border),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminTheme.statusSuccessBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.speed, color: AdminTheme.statusSuccess, size: 22),
              ),
              const SizedBox(width: 10),
              Text('System Diagnostics', style: AdminTheme.heading(17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHealthRow('FastAPI Core Server', 'Operational (24ms latency)', Icons.api, AdminTheme.statusSuccess),
              const SizedBox(height: 10),
              _buildHealthRow('SQLite Database', 'pawstay.db Active (0 Locks)', Icons.storage, AdminTheme.statusSuccess),
              const SizedBox(height: 10),
              _buildHealthRow('SMTP Mailer Engine', 'Gmail Gateway Connected', Icons.mark_email_read, AdminTheme.statusSuccess),
              const SizedBox(height: 10),
              _buildHealthRow('Real-time Socket.IO', 'Port 8000 Listening', Icons.wifi_tethering, AdminTheme.statusSuccess),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminTheme.cardBgSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('System Uptime:', style: AdminTheme.body(12, color: AdminTheme.textMuted)),
                    Text('99.98% • All Systems Go', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.statusSuccess)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close Diagnostics', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthRow(String title, String status, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AdminTheme.cardBgSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AdminTheme.textPrimary)),
                Text(status, style: AdminTheme.body(11, color: AdminTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationsSheet() {
    final notifications = [
      {
        'title': 'New Vet License Submitted',
        'desc': 'Dr. Michael Chang submitted license VET-TX-77312 for verification.',
        'time': '5 mins ago',
        'icon': Icons.medical_services_outlined,
        'color': AdminTheme.primary,
      },
      {
        'title': 'High Volume Order Placed',
        'desc': 'Order #PST-9840 placed for Luxury Dog Stay (\$144.00).',
        'time': '2 hours ago',
        'icon': Icons.shopping_bag_outlined,
        'color': AdminTheme.statusSuccess,
      },
      {
        'title': 'User Account Flagged',
        'desc': 'Account #USR-0004 flagged for profile review.',
        'time': 'Yesterday',
        'icon': Icons.warning_amber_rounded,
        'color': AdminTheme.statusWarning,
      },
      {
        'title': 'Database Backup Completed',
        'desc': 'SQLite pawstay.db successfully backed up to secure archive.',
        'time': '1 day ago',
        'icon': Icons.cloud_done_outlined,
        'color': AdminTheme.secondary,
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ValueListenableBuilder<bool>(
        valueListenable: AdminTheme.isDarkMode,
        builder: (context, isDark, _) => Container(
          decoration: BoxDecoration(
            color: AdminTheme.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AdminTheme.border),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications_active, color: AdminTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('System Alerts & Activity', style: AdminTheme.heading(16)),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Close', style: AdminTheme.body(12, color: AdminTheme.primary, weight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                itemCount: notifications.length,
                separatorBuilder: (c, i) => Divider(color: AdminTheme.border, height: 16),
                itemBuilder: (c, i) {
                  final n = notifications[i];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (n['color'] as Color).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(n['icon'] as IconData, color: n['color'] as Color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n['title'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AdminTheme.textPrimary)),
                            const SizedBox(height: 1),
                            Text(n['desc'] as String, style: AdminTheme.body(11, color: AdminTheme.textSecondary)),
                            const SizedBox(height: 2),
                            Text(n['time'] as String, style: AdminTheme.body(10, color: AdminTheme.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => ValueListenableBuilder<bool>(
        valueListenable: AdminTheme.isDarkMode,
        builder: (context, isDark, _) => AlertDialog(
          backgroundColor: AdminTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AdminTheme.border),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: AdminTheme.statusDanger),
              const SizedBox(width: 8),
              Text('Logout Admin?', style: AdminTheme.heading(16)),
            ],
          ),
          content: Text(
            'Are you sure you want to sign out of the PawStay Admin Panel? You will need your admin credentials to log back in.',
            style: AdminTheme.body(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: AdminTheme.body(12)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.statusDanger,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AdminTheme.isDarkMode,
      builder: (context, isDark, _) {
        return Scaffold(
          backgroundColor: AdminTheme.background,
          appBar: AppBar(
            backgroundColor: AdminTheme.cardBg,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleSpacing: 14,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: AdminTheme.border, height: 1),
            ),
            title: Row(
              children: [
                // PawStay Admin Brand Badge
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AdminTheme.primary, Color(0xFFFF7A45)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AdminTheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.pets, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'PawStay',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AdminTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AdminTheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ADMIN',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _showSystemHealthModal,
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AdminTheme.statusSuccess,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'FastAPI Live (24ms) • ${_titles[_selectedIndex]}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: AdminTheme.statusSuccess,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // Dark / Light Theme Toggle Switch
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    key: ValueKey<bool>(isDark),
                    color: isDark ? const Color(0xFFFBBF24) : AdminTheme.primary,
                    size: 22,
                  ),
                ),
                tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                onPressed: () => AdminTheme.toggleTheme(),
              ),

              // System Diagnostics / Server Status
              IconButton(
                icon: Icon(Icons.sensors, color: AdminTheme.statusSuccess, size: 22),
                tooltip: 'Server Health',
                onPressed: _showSystemHealthModal,
              ),

              // Notifications
              IconButton(
                icon: Stack(
                  children: [
                    Icon(Icons.notifications_outlined, color: AdminTheme.textPrimary, size: 22),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AdminTheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                tooltip: 'Alerts',
                onPressed: _showNotificationsSheet,
              ),

              // Logout Button
              IconButton(
                icon: Icon(Icons.logout, color: AdminTheme.statusDanger, size: 20),
                tooltip: 'Logout Admin',
                onPressed: _confirmLogout,
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: _pages[_selectedIndex],
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AdminTheme.cardBg,
              border: Border(top: BorderSide(color: AdminTheme.border)),
            ),
            child: NavigationBar(
              backgroundColor: AdminTheme.cardBg,
              indicatorColor: AdminTheme.primary.withValues(alpha: 0.15),
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.people_alt_outlined, color: AdminTheme.textMuted),
                  selectedIcon: Icon(Icons.people_alt, color: AdminTheme.primary),
                  label: 'Users',
                ),
                NavigationDestination(
                  icon: Icon(Icons.storefront_outlined, color: AdminTheme.textMuted),
                  selectedIcon: Icon(Icons.storefront, color: AdminTheme.primary),
                  label: 'Sellers',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined, color: AdminTheme.textMuted),
                  selectedIcon: Icon(Icons.insights, color: AdminTheme.primary),
                  label: 'Sales',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
