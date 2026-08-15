import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../theme/pawstay_theme.dart';
import '../config/api_config.dart';
import 'verify_otp.dart';
import 'login.dart';

// ── Indian States list (for autocomplete)
const List<String> _kIndianStates = [
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chhattisgarh',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
  'Chandigarh',
  'Dadra and Nagar Haveli',
  'Daman and Diu',
  'Delhi',
  'Jammu and Kashmir',
  'Ladakh',
  'Lakshadweep',
  'Puducherry',
];

// ── State to City suggestions map
const Map<String, List<String>> _kStateCityMap = {
  'Maharashtra': [
    'Mumbai',
    'Pune',
    'Nagpur',
    'Nashik',
    'Thane',
    'Aurangabad',
    'Solapur',
    'Navi Mumbai',
    'Kolhapur',
    'Amravati',
  ],
  'Delhi': [
    'New Delhi',
    'North Delhi',
    'South Delhi',
    'East Delhi',
    'West Delhi',
    'Central Delhi',
    'Dwarka',
    'Rohini',
  ],
  'Karnataka': [
    'Bangalore',
    'Mysore',
    'Hubli',
    'Mangalore',
    'Belgaum',
    'Davangere',
    'Bellary',
    'Gulbarga',
  ],
  'Tamil Nadu': [
    'Chennai',
    'Coimbatore',
    'Madurai',
    'Tiruchirappalli',
    'Salem',
    'Tirunelveli',
    'Vellore',
    'Erode',
  ],
  'Gujarat': [
    'Ahmedabad',
    'Surat',
    'Vadodara',
    'Rajkot',
    'Bhavnagar',
    'Jamnagar',
    'Gandhinagar',
    'Junagadh',
  ],
  'Uttar Pradesh': [
    'Lucknow',
    'Kanpur',
    'Agra',
    'Varanasi',
    'Ghaziabad',
    'Noida',
    'Meerut',
    'Prayagraj',
    'Bareilly',
    'Aligarh',
  ],
  'West Bengal': [
    'Kolkata',
    'Howrah',
    'Durgapur',
    'Asansol',
    'Siliguri',
    'Kharagpur',
  ],
  'Rajasthan': [
    'Jaipur',
    'Jodhpur',
    'Udaipur',
    'Kota',
    'Bikaner',
    'Ajmer',
    'Bhilwara',
  ],
  'Telangana': ['Hyderabad', 'Warangal', 'Nizamabad', 'Karimnagar', 'Khammam'],
  'Punjab': [
    'Ludhiana',
    'Amritsar',
    'Jalandhar',
    'Patiala',
    'Bathinda',
    'Mohali',
  ],
  'Haryana': [
    'Gurgaon',
    'Faridabad',
    'Panipat',
    'Ambala',
    'Karnal',
    'Hisar',
    'Rohtak',
  ],
  'Kerala': [
    'Kochi',
    'Thiruvananthapuram',
    'Kozhikode',
    'Thrissur',
    'Kollam',
    'Kannur',
  ],
  'Madhya Pradesh': [
    'Indore',
    'Bhopal',
    'Jabalpur',
    'Gwalior',
    'Ujjain',
    'Sagar',
  ],
  'Bihar': ['Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur', 'Purnia', 'Darbhanga'],
  'Andhra Pradesh': [
    'Visakhapatnam',
    'Vijayawada',
    'Guntur',
    'Nellore',
    'Kurnool',
    'Rajahmundry',
  ],
  'Assam': ['Guwahati', 'Silchar', 'Dibrugarh', 'Jorhat', 'Nagaon'],
  'Odisha': ['Bhubaneswar', 'Cuttack', 'Rourkela', 'Berhampur', 'Sambalpur'],
};

// ── Popular cities (fallback when state is not selected)
const List<String> _kPopularCities = [
  'Mumbai',
  'Delhi',
  'Bangalore',
  'Hyderabad',
  'Chennai',
  'Kolkata',
  'Pune',
  'Ahmedabad',
];

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtr = TextEditingController();
  final _usernameCtr = TextEditingController();
  final _emailCtr = TextEditingController();
  final _passwordCtr = TextEditingController();
  final _confirmPasswordCtr = TextEditingController();
  final _stateCtr = TextEditingController();
  final _cityCtr = TextEditingController();
  final _postalCtr = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String _selectedRole = 'User';
  final List<String> _roles = ['User', 'Pet Service', 'Seller', 'Doctor'];

  bool _isLoading = false;

  // ── Ultra-Fast Username Availability Check State
  bool?
  _usernameAvailable; // null = untouched/cleared, true = available, false = taken
  bool _checkingUsername = false;
  Timer? _usernameDebounce;
  http.Client? _usernameHttpClient;

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    _usernameHttpClient?.close();
    _usernameHttpClient = null;

    final username = value.trim();

    if (username.length < 3) {
      setState(() {
        _usernameAvailable = null;
        _checkingUsername = false;
      });
      return;
    }

    setState(() {
      _checkingUsername = true;
      _usernameAvailable = null;
    });

    // 150ms debounce for near-instant typing feedback
    _usernameDebounce = Timer(const Duration(milliseconds: 150), () async {
      _usernameHttpClient = http.Client();
      try {
        final uri = Uri.parse(
          '${ApiConfig.baseUrl}/check-username?username=${Uri.encodeComponent(username)}',
        );
        final res = await _usernameHttpClient!
            .get(uri)
            .timeout(const Duration(seconds: 4));

        if (!mounted) return;

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          setState(() {
            _usernameAvailable = data['success'] == true;
            _checkingUsername = false;
          });
        } else {
          setState(() => _checkingUsername = false);
        }
      } catch (e) {
        if (mounted && _checkingUsername) {
          setState(() => _checkingUsername = false);
        }
      }
    });
  }

  // Button bounce controller
  late AnimationController _buttonCtrl;

  @override
  void initState() {
    super.initState();
    _buttonCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _nameCtr.dispose();
    _usernameCtr.dispose();
    _emailCtr.dispose();
    _passwordCtr.dispose();
    _confirmPasswordCtr.dispose();
    _stateCtr.dispose();
    _cityCtr.dispose();
    _postalCtr.dispose();
    _buttonCtrl.dispose();
    _usernameDebounce?.cancel();
    _usernameHttpClient?.close();
    super.dispose();
  }

  List<String> _getCitySuggestions() {
    final selectedState = _stateCtr.text.trim();
    if (_kStateCityMap.containsKey(selectedState)) {
      return _kStateCityMap[selectedState]!;
    }
    return _kPopularCities;
  }

  TextStyle _inputStyle() {
    return GoogleFonts.plusJakartaSans(
      fontSize: 16,
      color: PawStayTheme.onSurface,
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: PawStayTheme.onSurface,
      ),
    );
  }

  // ── API call ─────────────────────────────────────────────────────────────
  Future<void> _onSignupPressed() async {
    _buttonCtrl.reverse().then((_) => _buttonCtrl.forward());

    if (!_formKey.currentState!.validate()) return;

    if (_usernameAvailable == false) {
      _showError('Username is already taken. Please choose another.');
      return;
    }

    if (_passwordCtr.text != _confirmPasswordCtr.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final body = jsonEncode({
        'full_name': _nameCtr.text.trim(),
        'username': _usernameCtr.text.trim(),
        'email': _emailCtr.text.trim(),
        'password': _passwordCtr.text,
        'state': _stateCtr.text.trim(),
        'city': _cityCtr.text.trim(),
        'postal_code': _postalCtr.text.trim(),
        'role': _selectedRole,
      });

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/signup'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Navigate to OTP screen
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (c, a, sa) => VerifyOtpScreen(
              email: _emailCtr.text.trim(),
              fullName: _nameCtr.text.trim(),
            ),
            transitionsBuilder: (c, a, sa, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: a, curve: Curves.easeInOut)),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      } else {
        final decoded = jsonDecode(response.body);
        final detail = decoded['detail'] ?? 'Signup failed. Please try again.';
        _showError(detail);
      }
    } on TimeoutException {
      _showError('Connection timed out. Is the backend running?');
    } catch (e) {
      _showError('Could not connect to server. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
        backgroundColor: PawStayTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Autocomplete field factory ────────────────────────────────────────────
  Widget _buildAutocompleteField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required List<String> options,
    required String? Function(String?) validator,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return const Iterable.empty();
        final lower = textEditingValue.text.toLowerCase();
        return options.where((o) => o.toLowerCase().contains(lower));
      },
      onSelected: (selection) {
        controller.text = selection;
        setState(() {}); // trigger rebuild so city suggestions update for state
      },
      fieldViewBuilder: (ctx, fieldCtrl, focusNode, onSubmitted) {
        fieldCtrl.text = controller.text;
        fieldCtrl.addListener(() {
          if (controller.text != fieldCtrl.text) {
            controller.text = fieldCtrl.text;
          }
        });
        return TextFormField(
          controller: fieldCtrl,
          focusNode: focusNode,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            color: PawStayTheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: PawStayTheme.outlineVariant),
          ),
          validator: validator,
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
            color: PawStayTheme.surfaceContainerLowest,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 340),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final option = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        option,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: PawStayTheme.onSurface,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PawStayTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PawStayTheme.marginMobile,
                vertical: PawStayTheme.unit * 1.5,
              ),
              child: Row(
                children: [
                  const Icon(Icons.pets, color: PawStayTheme.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'PawStay',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: PawStayTheme.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: PawStayTheme.marginMobile,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 420),
                      decoration: BoxDecoration(
                        color: PawStayTheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(
                          PawStayTheme.radiusLg,
                        ),
                        border: Border.all(
                          color: PawStayTheme.surfaceDim,
                          width: 1.0,
                        ),
                        boxShadow: PawStayTheme.ambientShadow1,
                      ),
                      padding: const EdgeInsets.all(PawStayTheme.gutter),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    'Create Account',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: PawStayTheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Join PawStay and find perfect care for your pet.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      color: PawStayTheme.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            // ── Full Name ────────────────────────────────
                            _label('Full Name'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _nameCtr,
                              style: _inputStyle(),
                              decoration: const InputDecoration(
                                hintText: 'Jane Doe',
                                prefixIcon: Icon(
                                  Icons.person_outline_rounded,
                                  color: PawStayTheme.outlineVariant,
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Please enter your name'
                                  : null,
                            ),

                            const SizedBox(height: 16),

                            // ── Username ─────────────────────────────────
                            _label('Username'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _usernameCtr,
                              style: _inputStyle(),
                              onChanged: _onUsernameChanged,
                              decoration: InputDecoration(
                                hintText: 'janedoe123',
                                prefixIcon: const Icon(
                                  Icons.alternate_email,
                                  color: PawStayTheme.outlineVariant,
                                ),
                                suffixIcon: _checkingUsername
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                              PawStayTheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      )
                                    : _usernameAvailable == true
                                    ? const Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFF4CAF50),
                                      )
                                    : _usernameAvailable == false
                                    ? const Icon(
                                        Icons.cancel_rounded,
                                        color: PawStayTheme.error,
                                      )
                                    : null,
                                helperText: _usernameAvailable == true
                                    ? 'Username is available ✓'
                                    : _usernameAvailable == false
                                    ? 'Username is already taken'
                                    : null,
                                helperStyle: TextStyle(
                                  color: _usernameAvailable == true
                                      ? const Color(0xFF4CAF50)
                                      : PawStayTheme.error,
                                  fontSize: 12,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Please enter a username';
                                }
                                if (v.trim().length < 3) {
                                  return 'Username must be at least 3 characters';
                                }
                                if (_usernameAvailable == false) {
                                  return 'This username is already taken';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // ── Email ────────────────────────────────────
                            _label('Email'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _emailCtr,
                              keyboardType: TextInputType.emailAddress,
                              style: _inputStyle(),
                              decoration: const InputDecoration(
                                hintText: 'jane@example.com',
                                prefixIcon: Icon(
                                  Icons.mail_outline_rounded,
                                  color: PawStayTheme.outlineVariant,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(
                                  r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$',
                                ).hasMatch(v)) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // ── Password ─────────────────────────────────
                            _label('Password'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordCtr,
                              obscureText: _obscurePassword,
                              style: _inputStyle(),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: PawStayTheme.outlineVariant,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: PawStayTheme.outlineVariant,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Please enter a password';
                                }
                                if (v.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // ── Confirm Password ──────────────────────────
                            _label('Confirm Password'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _confirmPasswordCtr,
                              obscureText: _obscureConfirmPassword,
                              style: _inputStyle(),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: PawStayTheme.outlineVariant,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: PawStayTheme.outlineVariant,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (v != _passwordCtr.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // ── State (with autocomplete) ─────────────────
                            _label('State'),
                            const SizedBox(height: 6),
                            _buildAutocompleteField(
                              label: 'State',
                              hint: 'e.g. Maharashtra',
                              icon: Icons.map_outlined,
                              controller: _stateCtr,
                              options: _kIndianStates,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Please select your state'
                                  : null,
                            ),

                            const SizedBox(height: 16),

                            // ── City (with state-based suggestions) ───────
                            _label('City'),
                            const SizedBox(height: 6),
                            _buildAutocompleteField(
                              label: 'City',
                              hint: 'e.g. Mumbai',
                              icon: Icons.location_city_outlined,
                              controller: _cityCtr,
                              options: _getCitySuggestions(),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Please enter your city'
                                  : null,
                            ),

                            const SizedBox(height: 16),

                            // ── Postal Code ───────────────────────────────
                            _label('Postal Code'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _postalCtr,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              style: _inputStyle(),
                              decoration: const InputDecoration(
                                hintText: '400001',
                                prefixIcon: Icon(
                                  Icons.pin_drop_outlined,
                                  color: PawStayTheme.outlineVariant,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Please enter your postal code';
                                }
                                if (v.length < 4) {
                                  return 'Postal code is too short';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // ── Role ──────────────────────────────────────
                            _label('Role'),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _selectedRole,
                              elevation: 2,
                              icon: const Icon(
                                Icons.expand_more,
                                color: PawStayTheme.onSurfaceVariant,
                              ),
                              dropdownColor:
                                  PawStayTheme.surfaceContainerLowest,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                color: PawStayTheme.onSurface,
                              ),
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                prefixIcon: Icon(
                                  Icons.supervised_user_circle_outlined,
                                  color: PawStayTheme.outlineVariant,
                                ),
                              ),
                              items: _roles
                                  .map(
                                    (role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(role),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedRole = val);
                                }
                              },
                            ),

                            const SizedBox(height: 28),

                            // ── Submit Button ─────────────────────────────
                            ScaleTransition(
                              scale: _buttonCtrl,
                              child: SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _onSignupPressed,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: PawStayTheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        100.0,
                                      ),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : Text(
                                          'Create Account',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── Already have an account? Login ────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account? ',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: PawStayTheme.onSurfaceVariant,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const LoginScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Log In',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: PawStayTheme.primary,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
