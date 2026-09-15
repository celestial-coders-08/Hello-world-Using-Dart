import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';
import '../../theme/pawstay_theme.dart';

class YourRatingScreen extends StatefulWidget {
  final String? providerLookup;
  final String? userLookup;

  const YourRatingScreen({super.key, this.providerLookup, this.userLookup});

  @override
  State<YourRatingScreen> createState() => _YourRatingScreenState();
}

class _YourRatingScreenState extends State<YourRatingScreen> {
  final _reviewController = TextEditingController();
  final Map<String, int> _categoryRatings = {
    'Punctuality': 5,
    'Communication': 5,
    'Pet Friendliness': 5,
    'Reliability': 5,
  };

  List<Map<String, dynamic>> _reviews = [];
  String _providerName = 'Service Provider';
  String _providerRole = 'Certified Sitter';
  bool _isLoading = true;
  bool _isSubmitting = false;
  Timer? _reviewRefreshTimer;

  bool get _canSubmit =>
      widget.userLookup != null && widget.userLookup!.trim().isNotEmpty;

  double get _formRating =>
      _categoryRatings.values.reduce((a, b) => a + b) / _categoryRatings.length;

  double get _averageRating {
    if (_reviews.isEmpty) return 0;
    final total = _reviews.fold<double>(
      0,
      (sum, review) => sum + ((review['rating'] as num?)?.toDouble() ?? 0),
    );
    return total / _reviews.length;
  }

  @override
  void initState() {
    super.initState();
    _loadProviderProfile();
    _loadReviews();
    if (!_canSubmit) {
      _reviewRefreshTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _loadReviews(),
      );
    }
  }

  @override
  void dispose() {
    _reviewRefreshTimer?.cancel();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    final lookup = widget.providerLookup?.trim();
    if (lookup == null || lookup.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final reviews = await ApiService.fetchProviderReviews(
      providerLookup: lookup,
    );
    if (mounted) {
      setState(() {
        _reviews = reviews;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProviderProfile() async {
    final lookup = widget.providerLookup?.trim();
    if (lookup == null || lookup.isEmpty) return;
    final profile = await ApiService.fetchProviderProfile(
      providerLookup: lookup,
    );
    if (!mounted || profile == null) return;
    final fullName = profile['full_name']?.toString().trim();
    final username = profile['username']?.toString().trim();
    final role = profile['role']?.toString().trim();
    setState(() {
      if (fullName != null && fullName.isNotEmpty) {
        _providerName = fullName;
      } else if (username != null && username.isNotEmpty) {
        _providerName = username;
      }
      if (role != null && role.isNotEmpty) _providerRole = role;
    });
  }

  Future<void> _submitReview() async {
    final provider = widget.providerLookup?.trim();
    final user = widget.userLookup?.trim();
    final description = _reviewController.text.trim();
    if (provider == null || provider.isEmpty || user == null || user.isEmpty) {
      _showMessage('Sign in as a client to submit a review.', isError: true);
      return;
    }
    if (description.isEmpty) {
      _showMessage('Please write a detail review.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ApiService.submitReview({
      'provider_lookup': provider,
      'user_lookup': user,
      'rating': _formRating.round(),
      'description': description,
    });
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (result == null) {
      _showMessage('Unable to submit your review.', isError: true);
      return;
    }

    _reviewController.clear();
    await _loadReviews();
    if (mounted) _showMessage('Review submitted successfully.');
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? PawStayTheme.error : PawStayTheme.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PawStayTheme.providerTheme,
      child: Scaffold(
        backgroundColor: PawStayTheme.background,
        appBar: AppBar(
          backgroundColor: PawStayTheme.background,
          elevation: 0,
          leading: const BackButton(),
          title: Text(
            'Provider Profile',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              onPressed: _loadReviews,
              tooltip: 'Refresh reviews',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        bottomNavigationBar: _canSubmit ? _buildBottomActions() : null,
        body: RefreshIndicator(
          color: PawStayTheme.primary,
          onRefresh: _loadReviews,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _buildProviderHeader(),
              const SizedBox(height: 16),
              _buildRatingSummary(),
              const SizedBox(height: 16),
              if (_canSubmit) _buildReviewForm(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Client Feedback',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_reviews.length} reviews',
                    style: GoogleFonts.plusJakartaSans(
                      color: PawStayTheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_reviews.isEmpty)
                _emptyReviews()
              else
                ..._reviews.map(_buildReviewCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: PawStayTheme.secondaryContainer,
          child: const Icon(Icons.pets_rounded, color: PawStayTheme.secondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _providerName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _providerRole,
                style: GoogleFonts.plusJakartaSans(
                  color: PawStayTheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSummary() {
    final rating = _reviews.isEmpty ? 0.0 : _averageRating;
    return _panel(
      child: Column(
        children: [
          Row(
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  color: PawStayTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 13),
                child: Text(
                  '/ 5.0',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _stars(rating, size: 19),
                  Text(
                    'Based on ${_reviews.length} client reviews',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: PawStayTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewForm() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rate this provider',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tell other pet parents about your experience.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: PawStayTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          ..._categoryRatings.keys.map(_buildCategoryPicker),
          const SizedBox(height: 8),
          TextField(
            controller: _reviewController,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Detailed review',
              hintText: 'Share what made the experience special...',
              alignLabelWithHint: true,
              filled: true,
              fillColor: PawStayTheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Overall rating: ${_formRating.toStringAsFixed(1)} / 5.0',
            style: GoogleFonts.plusJakartaSans(
              color: PawStayTheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitReview,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 17),
              label: Text(_isSubmitting ? 'Submitting...' : 'Submit review'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPicker(String category) {
    final selected = _categoryRatings[category]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(_categoryIcon(category), size: 19, color: PawStayTheme.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              category,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...List.generate(
            5,
            (index) => GestureDetector(
              onTap: () =>
                  setState(() => _categoryRatings[category] = index + 1),
              child: Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Icon(
                  index < selected
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 22,
                  color: PawStayTheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] as num?)?.toDouble() ?? 0;
    final name = (review['user_name'] ?? review['user_lookup'] ?? 'Client')
        .toString();
    final description = (review['description'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: PawStayTheme.secondaryContainer,
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: PawStayTheme.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  _formatDate(review['created_at']),
                  style: GoogleFonts.plusJakartaSans(
                    color: PawStayTheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _stars(rating, size: 17),
                const SizedBox(width: 8),
                Text(
                  rating.toStringAsFixed(1),
                  style: GoogleFonts.plusJakartaSans(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              description,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyReviews() {
    return _panel(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Text(
            'No reviews have been submitted yet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: PawStayTheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: FilledButton.icon(
        onPressed: _isSubmitting ? null : _submitReview,
        icon: const Icon(Icons.rate_review_outlined),
        label: const Text('Submit your review'),
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: PawStayTheme.ambientShadow1,
      ),
      child: child,
    );
  }

  Widget _stars(double rating, {double size = 18}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index + 0.5 < rating ? Icons.star_rounded : Icons.star_border_rounded,
          color: PawStayTheme.primary,
          size: size,
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Punctuality':
        return Icons.schedule_rounded;
      case 'Communication':
        return Icons.chat_bubble_outline_rounded;
      case 'Pet Friendliness':
        return Icons.favorite_border_rounded;
      default:
        return Icons.verified_user_outlined;
    }
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Recently';
    final days = DateTime.now().difference(date).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return '1 day ago';
    if (days < 7) return '$days days ago';
    return '${(days / 7).floor()}w ago';
  }
}
