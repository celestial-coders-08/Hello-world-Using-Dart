import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/seller_api_service.dart';
import '../../theme/pawstay_theme.dart';
import '../../widgets/profile_avatar.dart';
import '../auth/login.dart';

class SellerProfileScreen extends StatefulWidget {
  final String sellerLookup;

  const SellerProfileScreen({super.key, required this.sellerLookup});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  Map<String, dynamic>? _profile;
  String? _verificationStatus;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        SellerApiService.fetchSellerProfile(widget.sellerLookup),
        SellerApiService.fetchVerification(widget.sellerLookup),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0];
        _verificationStatus = results[1]['status']?.toString();
        _isLoading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('access_token');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName =
        _profile?['full_name']?.toString().trim().isNotEmpty == true
        ? _profile!['full_name'].toString()
        : 'Seller';
    return Scaffold(
      backgroundColor: PawStayTheme.background,
      appBar: AppBar(
        title: Text(
          'Seller Profile',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _loadProfile,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        ProfileAvatar(
                          name: fullName,
                          imageValue: _profile?['profile_image']?.toString(),
                          radius: 38,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          fullName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _profile?['role']?.toString() ?? 'Seller',
                          style: GoogleFonts.plusJakartaSans(
                            color: PawStayTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _infoTile('Username', _profile?['username']?.toString()),
                _infoTile('Email', _profile?['email']?.toString()),
                _infoTile(
                  'Seller verification',
                  _verificationStatus ?? 'Unknown',
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Log out'),
                ),
              ],
            ),
    );
  }

  Widget _infoTile(String title, String? value) {
    return Card(
      color: Colors.white,
      child: ListTile(
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: PawStayTheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        subtitle: Text(
          value?.isNotEmpty == true ? value! : 'Not available',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: PawStayTheme.onSurface,
          ),
        ),
      ),
    );
  }
}