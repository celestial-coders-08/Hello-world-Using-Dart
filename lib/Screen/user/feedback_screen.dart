import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/pawstay_theme.dart';
import '../../widgets/app_drawer.dart';

class FeedbackScreen extends StatefulWidget {
  final String? userLookup;

  const FeedbackScreen({super.key, this.userLookup});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int _selectedStars = 5;
  String _selectedCategory = 'App Design / Usability';
  final TextEditingController _feedbackController = TextEditingController();
  bool _hasAttachment = false;

  final List<String> _categories = [
    'App Design / Usability',
    'Vet & Doctor Booking',
    'Food & Product Store',
    'Customer Support',
    'Bug Report',
    'Feature Request',
  ];

  final List<Map<String, dynamic>> _myFeedbackHistory = [
    {
      'date': 'Yesterday',
      'stars': 5,
      'category': 'Vet & Doctor Booking',
      'comment':
          'Booking doctor Jenkins was super fast and easy! Loved the video call option.',
      'status': 'Reviewed',
    },
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  String get _ratingLabel {
    switch (_selectedStars) {
      case 1:
        return '1 Star • Disappointing';
      case 2:
        return '2 Stars • Needs Improvement';
      case 3:
        return '3 Stars • Average Experience';
      case 4:
        return '4 Stars • Very Good';
      case 5:
        return '5 Stars • Outstanding!';
      default:
        return 'Tap stars to rate';
    }
  }

  void _submitFeedback() {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a short comment before submitting.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          backgroundColor: PawStayTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _myFeedbackHistory.insert(0, {
        'date': 'Just Now',
        'stars': _selectedStars,
        'category': _selectedCategory,
        'comment': text,
        'status': 'Submitted',
      });
      _feedbackController.clear();
      _hasAttachment = false;
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: PawStayTheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: PawStayTheme.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Thank You!',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Text(
          'Your feedback helps us continuously improve PawStay for pets and parents worldwide!',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: PawStayTheme.secondary,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Done',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Feedback & Support',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
      ),
      drawer: AppDrawer(userLookup: widget.userLookup, activeRoute: 'feedback'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(PawStayTheme.marginMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rating Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    PawStayTheme.primaryContainer.withValues(alpha: 0.3),
                    PawStayTheme.secondaryContainer.withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
                border: Border.all(
                  color: PawStayTheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'How is your experience with PawStay?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Animated Star Picker
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starNum = index + 1;
                      final isFilled = starNum <= _selectedStars;
                      return IconButton(
                        iconSize: 36,
                        icon: Icon(
                          isFilled
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: isFilled
                              ? Colors.amber
                              : theme.colorScheme.outline,
                        ),
                        onPressed: () =>
                            setState(() => _selectedStars = starNum),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _ratingLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: PawStayTheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Category Selection
            Text(
              'Select Category',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(
                    cat,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: theme.colorScheme.primary,
                  onSelected: (sel) {
                    if (sel) setState(() => _selectedCategory = cat);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Message text area
            Text(
              'Your Comments / Suggestions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _feedbackController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Tell us what you liked or what we can fix...',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
              ),
            ),

            const SizedBox(height: 12),

            // Attachment Simulation
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _hasAttachment = !_hasAttachment);
                  },
                  icon: Icon(
                    _hasAttachment
                        ? Icons.check_circle_rounded
                        : Icons.attach_file_rounded,
                    color: _hasAttachment ? PawStayTheme.secondary : null,
                  ),
                  label: Text(
                    _hasAttachment
                        ? 'Screenshot attached'
                        : 'Attach Screenshot',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitFeedback,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  'Submit Feedback',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Submission History
            if (_myFeedbackHistory.isNotEmpty) ...[
              Text(
                'Recent Submissions',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _myFeedbackHistory.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final fb = _myFeedbackHistory[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        PawStayTheme.radiusDefault,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Row(
                                children: List.generate(
                                  fb['stars'] as int,
                                  (i) => const Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                fb['category'],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: PawStayTheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  fb['status'],
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: PawStayTheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            fb['comment'],
                            style: GoogleFonts.plusJakartaSans(fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              fb['date'],
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
