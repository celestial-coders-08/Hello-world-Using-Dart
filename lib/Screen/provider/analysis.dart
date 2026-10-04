import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';
import '../../theme/pawstay_theme.dart';

class AnalysisScreen extends StatefulWidget {
  final String? providerLookup;

  const AnalysisScreen({super.key, this.providerLookup});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final lookup = widget.providerLookup?.trim();
    if (lookup == null || lookup.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    final reviews = await ApiService.fetchProviderReviews(
      providerLookup: lookup,
    );
    if (!mounted) return;
    setState(() {
      _reviews = reviews;
      _isLoading = false;
    });
  }

  double? _ratingFor(Map<String, dynamic> review) {
    final value = review['rating'];
    final rating = value is num ? value.toDouble() : double.tryParse('$value');
    if (rating == null || rating < 1 || rating > 5) return null;
    return rating;
  }

  int _monthKey(DateTime date) => date.year * 12 + date.month;

  List<_MonthlyRating> _monthlyRatings(DateTime now) {
    final months = List.generate(6, (index) {
      final date = DateTime(now.year, now.month - 5 + index);
      return _MonthlyRating(date);
    });
    final monthByKey = {
      for (final month in months) _monthKey(month.month): month,
    };

    for (final review in _reviews) {
      final rating = _ratingFor(review);
      final createdAt = DateTime.tryParse(
        review['created_at']?.toString() ?? '',
      );
      if (rating == null || createdAt == null) continue;
      monthByKey[_monthKey(createdAt)]?.add(rating);
    }
    return months;
  }

  @override
  Widget build(BuildContext context) {
    final validRatings = _reviews
        .map(_ratingFor)
        .whereType<double>()
        .toList(growable: false);
    final averageRating = validRatings.isEmpty
        ? null
        : validRatings.reduce((total, rating) => total + rating) /
              validRatings.length;
    final monthlyRatings = _monthlyRatings(DateTime.now());

    return Theme(
      data: PawStayTheme.providerTheme,
      child: Scaffold(
        backgroundColor: PawStayTheme.background,
        appBar: AppBar(
          backgroundColor: PawStayTheme.background,
          elevation: 0,
          leading: const BackButton(),
          title: Text(
            'Analysis',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              onPressed: _isLoading ? null : _loadReviews,
              tooltip: 'Refresh ratings',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: PawStayTheme.primary),
              )
            : RefreshIndicator(
                color: PawStayTheme.primary,
                onRefresh: _loadReviews,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummary(averageRating, validRatings.length),
                    const SizedBox(height: 16),
                    _buildRatingGraph(monthlyRatings),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSummary(double? averageRating, int reviewCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
        boxShadow: PawStayTheme.ambientShadow1,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.star_rounded, color: Color(0xFFD97706)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  averageRating?.toStringAsFixed(1) ?? '--',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: PawStayTheme.onSurface,
                  ),
                ),
                Text(
                  'Average rating from $reviewCount '
                  '${reviewCount == 1 ? 'review' : 'reviews'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: PawStayTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '/ 5.0',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: PawStayTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingGraph(List<_MonthlyRating> months) {
    final hasRatings = months.any((month) => month.count > 0);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
        boxShadow: PawStayTheme.ambientShadow1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rating Graph',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: PawStayTheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Monthly average based on submitted client reviews',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: PawStayTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          if (!hasRatings)
            SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  widget.providerLookup?.trim().isNotEmpty == true
                      ? 'No dated ratings to display yet.'
                      : 'Provider information is unavailable.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: PawStayTheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 212,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: months.map(_buildMonthBar).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthBar(_MonthlyRating month) {
    final average = month.average;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          children: [
            SizedBox(
              height: 20,
              child: FittedBox(
                child: Text(
                  average?.toStringAsFixed(1) ?? '--',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: average == null
                        ? PawStayTheme.onSurfaceVariant
                        : PawStayTheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final barHeight = average == null
                      ? 0.0
                      : constraints.maxHeight * average / 5;
                  return Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        width: 24,
                        decoration: BoxDecoration(
                          color: PawStayTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      if (average != null)
                        Container(
                          width: 24,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: PawStayTheme.secondary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _monthLabel(month.month.month),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: PawStayTheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${month.count} ${month.count == 1 ? 'review' : 'reviews'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 8,
                color: PawStayTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthLabel(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}

class _MonthlyRating {
  final DateTime month;
  double _total = 0;
  int count = 0;

  _MonthlyRating(this.month);

  double? get average => count == 0 ? null : _total / count;

  void add(double rating) {
    _total += rating;
    count++;
  }
}