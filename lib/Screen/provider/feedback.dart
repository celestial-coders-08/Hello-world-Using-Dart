import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/pawstay_theme.dart';

class FeedbackScreen extends StatefulWidget {
  final String? providerLookup;

  const FeedbackScreen({super.key, this.providerLookup});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  int _selectedStars = 0;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submitFeedback() {
    final description = _descriptionController.text.trim();
    if (_selectedStars == 0 || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedStars == 0
                ? 'Please select a star rating.'
                : 'Please enter a suggestion or feature request.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          backgroundColor: PawStayTheme.error,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Thank you for your feedback!',
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
        backgroundColor: PawStayTheme.secondary,
      ),
    );
    setState(() {
      _selectedStars = 0;
      _descriptionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PawStayTheme.background,
      appBar: AppBar(
        backgroundColor: PawStayTheme.background,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back to dashboard',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Feedback',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(PawStayTheme.marginMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rate your experience',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: PawStayTheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                final star = index + 1;
                return IconButton(
                  tooltip: '$star ${star == 1 ? 'star' : 'stars'}',
                  onPressed: () => setState(() => _selectedStars = star),
                  icon: Icon(
                    star <= _selectedStars
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: Colors.amber.shade700,
                    size: 34,
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            Text(
              'Suggestions & Feature Requests',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: PawStayTheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Your suggestion',
                hintText: 'What would you like us to add or improve?',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PawStayTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
                  ),
                ),
                child: Text(
                  'Submit Feedback',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
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
