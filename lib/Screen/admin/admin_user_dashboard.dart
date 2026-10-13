import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import 'admin_theme.dart';

class UserModel {
  final int id;
  final String fullName;
  final String username;
  final String email;
  final String phone;
  final String city;
  final String role;
  final int petCount;
  final String createdAt;
  bool isVerified;
  bool isSuspended;

  UserModel({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.phone,
    required this.city,
    required this.role,
    required this.petCount,
    required this.createdAt,
    required this.isVerified,
    this.isSuspended = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 1,
      fullName: json['full_name'] ?? 'PawStay User',
      username: json['username'] ?? 'user',
      email: json['email'] ?? 'user@pawstay.com',
      phone: json['phone_number'] ?? '+1 234 567 8900',
      city: json['city'] ?? 'New York',
      role: json['role'] ?? 'User',
      petCount: json['pet_count'] ?? 1,
      createdAt: json['created_at'] ?? 'Oct 2024',
      isVerified: json['is_verified'] == true || json['status'] == 'Active',
      isSuspended: json['status'] == 'Suspended',
    );
  }
}

class AdminUserDashboard extends StatefulWidget {
  const AdminUserDashboard({super.key});

  @override
  State<AdminUserDashboard> createState() => _AdminUserDashboardState();
}

class _AdminUserDashboardState extends State<AdminUserDashboard> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  bool _isLoading = false;

  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadUsers() async {
    setState(() => _isLoading = true);

    final initialList = [
      UserModel(
        id: 1,
        fullName: 'Sarah Jenkins',
        username: 'sarah_j',
        email: 'sarah.j@gmail.com',
        phone: '+1 (555) 234-5678',
        city: 'San Francisco, CA',
        role: 'Pet Parent',
        petCount: 2,
        createdAt: 'Oct 04, 2024',
        isVerified: true,
      ),
      UserModel(
        id: 2,
        fullName: 'David Miller',
        username: 'david_m',
        email: 'david.miller@yahoo.com',
        phone: '+1 (555) 876-5432',
        city: 'Austin, TX',
        role: 'Pet Parent',
        petCount: 1,
        createdAt: 'Oct 03, 2024',
        isVerified: true,
      ),
      UserModel(
        id: 3,
        fullName: 'Elena Rostova',
        username: 'elena_r',
        email: 'elena.rostova@outlook.com',
        phone: '+1 (555) 432-1098',
        city: 'Seattle, WA',
        role: 'Pet Parent',
        petCount: 3,
        createdAt: 'Oct 02, 2024',
        isVerified: false,
      ),
      UserModel(
        id: 4,
        fullName: 'Marcus Vance',
        username: 'marcus_v',
        email: 'marcus.vance@tech.co',
        phone: '+1 (555) 901-2345',
        city: 'Chicago, IL',
        role: 'Pet Parent',
        petCount: 1,
        createdAt: 'Sep 29, 2024',
        isVerified: true,
        isSuspended: true,
      ),
      UserModel(
        id: 5,
        fullName: 'Priya Sharma',
        username: 'priya_s',
        email: 'priya.sharma@gmail.com',
        phone: '+1 (555) 678-1234',
        city: 'Boston, MA',
        role: 'Pet Parent',
        petCount: 2,
        createdAt: 'Sep 28, 2024',
        isVerified: true,
      ),
    ];

    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/admin/users'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final fetched = data.map((e) => UserModel.fromJson(e)).toList();
          _users = [...fetched, ...initialList];
        } else {
          _users = initialList;
        }
      } else {
        _users = initialList;
      }
    } catch (_) {
      _users = initialList;
    }

    _applyFilter();
    if (mounted) setState(() => _isLoading = false);
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredUsers = _users.where((user) {
        final matchesQuery = user.fullName.toLowerCase().contains(query) ||
            user.username.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            user.city.toLowerCase().contains(query);

        if (!matchesQuery) return false;

        if (_selectedFilter == 'Active') {
          return user.isVerified && !user.isSuspended;
        } else if (_selectedFilter == 'Pending') {
          return !user.isVerified;
        } else if (_selectedFilter == 'Suspended') {
          return user.isSuspended;
        }
        return true;
      }).toList();
    });
  }

  void _showAddUserModal() {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final cityCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: AdminTheme.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AdminTheme.border),
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Add New User', style: AdminTheme.heading(18)),
                    IconButton(
                      icon: Icon(Icons.close, color: AdminTheme.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildModalTextField('Full Name', nameCtrl, Icons.person_outline),
                const SizedBox(height: 10),
                _buildModalTextField('Username', userCtrl, Icons.alternate_email),
                const SizedBox(height: 10),
                _buildModalTextField('Email Address', emailCtrl, Icons.mail_outline),
                const SizedBox(height: 10),
                _buildModalTextField('Phone Number', phoneCtrl, Icons.phone_outlined),
                const SizedBox(height: 10),
                _buildModalTextField('City / Location', cityCtrl, Icons.location_on_outlined),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill Name and Email'),
                            backgroundColor: AdminTheme.statusDanger,
                          ),
                        );
                        return;
                      }
                      final newUser = UserModel(
                        id: _users.length + 10,
                        fullName: nameCtrl.text.trim(),
                        username: userCtrl.text.trim().isEmpty ? 'user_${_users.length + 1}' : userCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim().isEmpty ? '+1 (555) 000-1111' : phoneCtrl.text.trim(),
                        city: cityCtrl.text.trim().isEmpty ? 'PawStay City' : cityCtrl.text.trim(),
                        role: 'Pet Parent',
                        petCount: 1,
                        createdAt: 'Just now',
                        isVerified: true,
                      );
                      setState(() {
                        _users.insert(0, newUser);
                        _applyFilter();
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('User ${newUser.fullName} created successfully!'),
                          backgroundColor: AdminTheme.secondary,
                        ),
                      );
                    },
                    child: Text('Create Account', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalTextField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      style: GoogleFonts.plusJakartaSans(color: AdminTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(color: AdminTheme.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: AdminTheme.primary, size: 20),
        filled: true,
        fillColor: AdminTheme.background,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AdminTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AdminTheme.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  void _showUserDetailsModal(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AdminTheme.primaryContainer,
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: AdminTheme.heading(16)),
                      Text('@${user.username} • ID: #USR-${user.id.toString().padLeft(4, '0')}', style: AdminTheme.body(12, color: AdminTheme.primary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: user.isSuspended
                        ? AdminTheme.statusDangerBg
                        : (user.isVerified ? AdminTheme.statusSuccessBg : AdminTheme.statusWarningBg),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    user.isSuspended ? 'SUSPENDED' : (user.isVerified ? 'ACTIVE' : 'PENDING'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: user.isSuspended
                          ? AdminTheme.statusDanger
                          : (user.isVerified ? AdminTheme.statusSuccess : AdminTheme.statusWarning),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AdminTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminTheme.border),
              ),
              child: Column(
                children: [
                  _buildDetailRow(Icons.mail_outline, 'Email', user.email),
                  Divider(color: AdminTheme.border, height: 16),
                  _buildDetailRow(Icons.phone_outlined, 'Phone', user.phone),
                  Divider(color: AdminTheme.border, height: 16),
                  _buildDetailRow(Icons.location_city, 'Location', user.city),
                  Divider(color: AdminTheme.border, height: 16),
                  _buildDetailRow(Icons.pets, 'Registered Pets', '${user.petCount} Pets (Dog, Cat)'),
                  Divider(color: AdminTheme.border, height: 16),
                  _buildDetailRow(Icons.calendar_today, 'Joined Date', user.createdAt),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: user.isSuspended ? AdminTheme.secondary : AdminTheme.statusDanger,
                      side: BorderSide(
                        color: user.isSuspended ? AdminTheme.secondary : AdminTheme.statusDanger,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(user.isSuspended ? Icons.lock_open : Icons.block, size: 16),
                    label: Text(user.isSuspended ? 'Unban' : 'Suspend', style: const TextStyle(fontSize: 13)),
                    onPressed: () {
                      setState(() {
                        user.isSuspended = !user.isSuspended;
                        _applyFilter();
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(user.isSuspended ? 'User suspended' : 'User unbanned'),
                          backgroundColor: user.isSuspended ? AdminTheme.statusDanger : AdminTheme.secondary,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.send_outlined, size: 16, color: Colors.white),
                    label: Text('Reset Pass', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Password reset instructions sent to ${user.email}'),
                          backgroundColor: AdminTheme.secondary,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AdminTheme.textMuted),
        const SizedBox(width: 8),
        Text(label, style: AdminTheme.body(12, color: AdminTheme.textMuted)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AdminTheme.textPrimary,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _users.where((u) => u.isVerified && !u.isSuspended).length;
    final pendingCount = _users.where((u) => !u.isVerified).length;
    final suspendedCount = _users.where((u) => u.isSuspended).length;

    return ValueListenableBuilder<bool>(
      valueListenable: AdminTheme.isDarkMode,
      builder: (context, isDark, _) => RefreshIndicator(
        onRefresh: () async => _loadUsers(),
        color: AdminTheme.primary,
        backgroundColor: AdminTheme.cardBg,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Dashboard Title & Add User Action
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User Dashboard', style: AdminTheme.heading(20)),
                      const SizedBox(height: 2),
                      Text('Manage all registered PawStay accounts', style: AdminTheme.body(12)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 16),
                  label: Text('Add', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                  onPressed: _showAddUserModal,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Top Metric Cards Responsive Grid (2x2 on phones)
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildMetricCard('Total Users', '1,428', '+14.8% growth', Icons.people_alt_outlined, AdminTheme.primary, cardWidth),
                    _buildMetricCard('Active Today', '348', 'Live on app', Icons.bolt, AdminTheme.secondary, cardWidth),
                    _buildMetricCard('Verified %', '94.4%', '1,348 verified', Icons.verified_user_outlined, const Color(0xFFD97757), cardWidth),
                    _buildMetricCard('Total Pets', '892', 'Dogs & Cats', Icons.pets, const Color(0xFF506447), cardWidth),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // Weekly Registration Growth Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AdminTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Weekly Signups Trend', style: AdminTheme.heading(15)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AdminTheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Last 7 Days', style: AdminTheme.body(10, color: AdminTheme.primary, weight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 110,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildChartBar('Mon', 24, 0.4),
                        _buildChartBar('Tue', 38, 0.65),
                        _buildChartBar('Wed', 29, 0.5),
                        _buildChartBar('Thu', 45, 0.8),
                        _buildChartBar('Fri', 52, 0.9),
                        _buildChartBar('Sat', 60, 1.0, isHighest: true),
                        _buildChartBar('Sun', 42, 0.75),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Search Bar & Filter Chips
            Container(
              padding: const EdgeInsets.all(12),
              decoration: AdminTheme.cardDecoration(),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    style: GoogleFonts.plusJakartaSans(color: AdminTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search user by Name, Email or City...',
                      hintStyle: GoogleFonts.plusJakartaSans(color: AdminTheme.textMuted, fontSize: 12),
                      prefixIcon: Icon(Icons.search, color: AdminTheme.primary, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: AdminTheme.textMuted, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilter();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AdminTheme.background,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AdminTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AdminTheme.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', _users.length),
                        const SizedBox(width: 6),
                        _buildFilterChip('Active', activeCount),
                        const SizedBox(width: 6),
                        _buildFilterChip('Pending', pendingCount),
                        const SizedBox(width: 6),
                        _buildFilterChip('Suspended', suspendedCount),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // User List Header
            Text('User Directory (${_filteredUsers.length})', style: AdminTheme.heading(16)),
            const SizedBox(height: 10),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AdminTheme.primary),
                ),
              )
            else if (_filteredUsers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: AdminTheme.cardDecoration(),
                child: Column(
                  children: [
                    Icon(Icons.person_search, size: 40, color: AdminTheme.textMuted),
                    const SizedBox(height: 8),
                    Text('No matching users found', style: AdminTheme.body(13)),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredUsers.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final user = _filteredUsers[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: AdminTheme.cardDecoration(),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: user.isSuspended
                              ? AdminTheme.statusDangerBg
                              : AdminTheme.primaryContainer,
                          child: Text(
                            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: user.isSuspended ? AdminTheme.statusDanger : AdminTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      user.fullName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AdminTheme.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: user.isSuspended
                                          ? AdminTheme.statusDangerBg
                                          : (user.isVerified ? AdminTheme.statusSuccessBg : AdminTheme.statusWarningBg),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      user.isSuspended ? 'Suspended' : (user.isVerified ? 'Active' : 'Pending'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: user.isSuspended
                                            ? AdminTheme.statusDanger
                                            : (user.isVerified ? AdminTheme.statusSuccess : AdminTheme.statusWarning),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('${user.email} • ${user.city}', style: AdminTheme.body(11, color: AdminTheme.textMuted), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.pets, size: 11, color: AdminTheme.primary),
                                  const SizedBox(width: 3),
                                  Text('${user.petCount} Pets', style: AdminTheme.body(10, color: AdminTheme.textSecondary)),
                                  const SizedBox(width: 8),
                                  Text('Joined ${user.createdAt}', style: AdminTheme.body(10, color: AdminTheme.textMuted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right, color: AdminTheme.textMuted, size: 20),
                          onPressed: () => _showUserDetailsModal(user),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildMetricCard(String title, String value, String subtext, IconData icon, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(title, style: AdminTheme.body(11, color: AdminTheme.textMuted), overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: AdminTheme.heading(18, color: AdminTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(subtext, style: AdminTheme.body(10, color: color), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildChartBar(String label, int count, double percentage, {bool isHighest = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$count',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isHighest ? AdminTheme.primary : AdminTheme.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 18,
          height: 60 * percentage,
          decoration: BoxDecoration(
            color: isHighest ? AdminTheme.primary : AdminTheme.primaryLight,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: AdminTheme.body(10, color: AdminTheme.textSecondary)),
      ],
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
          _applyFilter();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AdminTheme.primary : AdminTheme.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AdminTheme.primary : AdminTheme.border,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AdminTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black.withValues(alpha: 0.2) : AdminTheme.background,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AdminTheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
