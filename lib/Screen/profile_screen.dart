import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/api_config.dart';
import '../theme/pawstay_theme.dart';
import 'login.dart';

class ProfileScreen extends StatefulWidget {
  final String userLookup;

  const ProfileScreen({super.key, required this.userLookup});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  bool _isDeletingAccount = false;

  String get _normalizedLookup => widget.userLookup.trim();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  static String? _cachedBaseUrl;

  List<String> get _candidateBaseUrls => [
    if (_cachedBaseUrl != null) _cachedBaseUrl!,
    ApiConfig.baseUrl,
    'http://10.0.2.2:8000',
    'http://127.0.0.1:8000',
    'http://localhost:8000',
  ];

  Future<http.Response> _getWithFallback(String path) async {
    Object? lastException;
    for (final baseUrl in _candidateBaseUrls) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl$path'))
            .timeout(const Duration(seconds: 5));
        _cachedBaseUrl = baseUrl;
        return response;
      } catch (e) {
        lastException = e;
      }
    }
    throw lastException ?? Exception('Failed to connect to backend server');
  }

  Future<http.Response> _postWithFallback(String path, String body) async {
    Object? lastException;
    for (final baseUrl in _candidateBaseUrls) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl$path'),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 10));
        _cachedBaseUrl = baseUrl;
        return response;
      } catch (e) {
        lastException = e;
      }
    }
    throw lastException ?? Exception('Failed to connect to backend server');
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
        backgroundColor: isError ? PawStayTheme.error : PawStayTheme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final response = await _getWithFallback(
        '/profile?lookup=${Uri.encodeQueryComponent(_normalizedLookup)}',
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        setState(() {
          _profile = jsonDecode(response.body) as Map<String, dynamic>;
        });
      } else {
        final decoded = jsonDecode(response.body);
        _showSnack(
          decoded['detail']?.toString() ?? 'Failed to load profile.',
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) {
        _showSnack('Could not connect to server.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 70,
      );

      if (file == null) {
        return;
      }

      setState(() => _isUploadingPhoto = true);

      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final response = await _postWithFallback(
        '/profile/photo',
        jsonEncode({'lookup': _normalizedLookup, 'profile_image': base64Image}),
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        await _loadProfile();
        _showSnack('Profile photo updated successfully.');
      } else {
        final decoded = jsonDecode(response.body);
        _showSnack(
          decoded['detail']?.toString() ?? 'Failed to update profile photo.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Error uploading photo: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: !_isDeletingAccount,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Delete Account',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your password to permanently delete this account.',
                    style: GoogleFonts.plusJakartaSans(
                      color: PawStayTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isDeletingAccount
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isDeletingAccount
                      ? null
                      : () async {
                          final password = passwordController.text;
                          if (password.trim().isEmpty) {
                            _showSnack(
                              'Please enter your password.',
                              isError: true,
                            );
                            return;
                          }

                          setState(() => _isDeletingAccount = true);

                          try {
                            final response = await _postWithFallback(
                              '/delete-account',
                              jsonEncode({
                                'lookup': _normalizedLookup,
                                'password': password,
                              }),
                            );

                            if (!mounted) {
                              return;
                            }

                            if (response.statusCode == 200) {
                              Navigator.of(dialogContext).pop();
                              _showSnack('Account deleted successfully.');
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            } else {
                              final decoded = jsonDecode(response.body);
                              _showSnack(
                                decoded['detail']?.toString() ??
                                    'Failed to delete account.',
                                isError: true,
                              );
                            }
                          } catch (_) {
                            if (mounted) {
                              _showSnack(
                                'Could not connect to server.',
                                isError: true,
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isDeletingAccount = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PawStayTheme.error,
                    foregroundColor: Colors.white,
                  ),
                  child: _isDeletingAccount
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
  }

  Widget _buildInfoCard(String label, String value, {Widget? trailing}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PawStayTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
        border: Border.all(color: PawStayTheme.surfaceDim),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: PawStayTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: PawStayTheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  ImageProvider? _buildProfileImage(String? base64Image) {
    if (base64Image == null || base64Image.trim().isEmpty) {
      return null;
    }
    try {
      final bytes = base64Decode(base64Image);
      return MemoryImage(Uint8List.fromList(bytes));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final profileImage = _buildProfileImage(
      profile?['profile_image']?.toString(),
    );
    final displayName = profile?['full_name']?.toString() ?? 'User';
    final username = profile?['username']?.toString() ?? '@user';
    final email = profile?['email']?.toString() ?? '';

    return Scaffold(
      backgroundColor: PawStayTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Profile',
          style: GoogleFonts.plusJakartaSans(
            color: PawStayTheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : profile == null
          ? Center(
              child: Text(
                'Could not load profile.',
                style: GoogleFonts.plusJakartaSans(
                  color: PawStayTheme.onSurfaceVariant,
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(PawStayTheme.marginMobile),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: PawStayTheme.primaryContainer,
                              backgroundImage: profileImage,
                              child: profileImage == null
                                  ? Text(
                                      displayName.isEmpty
                                          ? 'U'
                                          : displayName[0].toUpperCase(),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: PawStayTheme.primary,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: InkWell(
                                onTap: _isUploadingPhoto
                                    ? null
                                    : _pickAndUploadPhoto,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: const BoxDecoration(
                                    color: PawStayTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: _isUploadingPhoto
                                      ? const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.add_a_photo_outlined,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          displayName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: PawStayTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@$username',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            color: PawStayTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'ACCOUNT INFORMATION',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: PawStayTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard('Full Name', displayName),
                  const SizedBox(height: 12),
                  _buildInfoCard('Username', '@$username'),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    'Email Address',
                    email,
                    trailing: Icon(
                      profile['is_verified'] == true
                          ? Icons.verified_outlined
                          : Icons.info_outline,
                      color: profile['is_verified'] == true
                          ? PawStayTheme.secondary
                          : PawStayTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard('Role', profile['role']?.toString() ?? 'User'),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(
                        'Log Out',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'DANGER ZONE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: PawStayTheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: PawStayTheme.errorContainer.withValues(
                        alpha: 0.35,
                      ),
                      borderRadius: BorderRadius.circular(
                        PawStayTheme.radiusMd,
                      ),
                      border: Border.all(
                        color: PawStayTheme.error.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Account',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: PawStayTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Once you delete your account, there is no going back. Please be certain.',
                          style: GoogleFonts.plusJakartaSans(
                            color: PawStayTheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _showDeleteAccountDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PawStayTheme.error,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            'Delete Account',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
