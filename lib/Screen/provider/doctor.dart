import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/pawstay_theme.dart';

class DoctorScreen extends StatefulWidget {
  final String? userLookup;

  const DoctorScreen({super.key, this.userLookup});

  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'General Vet',
    'Dentistry',
    'Emergency & Trauma',
    'Dermatology',
    'Surgery',
  ];

  // Mock list of doctors
  final List<Map<String, dynamic>> _doctors = [
    {
      'id': 'doc-1',
      'name': 'Dr. Sarah Jenkins, DVM',
      'specialty': 'General Vet',
      'rating': 4.9,
      'reviewsCount': 142,
      'experience': '12 yrs exp',
      'fee': '\$45',
      'location': 'City Pet Clinic, Downtown (1.2 mi)',
      'availableSlot': 'Today, 03:00 PM',
      'avatarColor': Colors.teal,
      'bio':
          'Specialist in canine & feline internal medicine and preventive wellness care.',
    },
    {
      'id': 'doc-2',
      'name': 'Dr. Michael Chang, BVSc',
      'specialty': 'Emergency & Trauma',
      'rating': 4.8,
      'reviewsCount': 98,
      'experience': '9 yrs exp',
      'fee': '\$60',
      'location': '24/7 Animal ER Center (2.5 mi)',
      'availableSlot': 'Today, 01:30 PM',
      'avatarColor': PawStayTheme.primary,
      'bio':
          'Critical care and trauma specialist for dogs, cats, and small exotic animals.',
    },
    {
      'id': 'doc-3',
      'name': 'Dr. Elena Rostova, DVM, MS',
      'specialty': 'Dentistry',
      'rating': 4.95,
      'reviewsCount': 86,
      'experience': '15 yrs exp',
      'fee': '\$55',
      'location': 'Bright Paws Dental & Care (3.1 mi)',
      'availableSlot': 'Tomorrow, 10:00 AM',
      'avatarColor': PawStayTheme.secondary,
      'bio':
          'Veterinary dentistry expert focused on oral health, cleanings, and surgical extractions.',
    },
    {
      'id': 'doc-4',
      'name': 'Dr. Robert Miller, DVM',
      'specialty': 'Dermatology',
      'rating': 4.7,
      'reviewsCount': 64,
      'experience': '7 yrs exp',
      'fee': '\$50',
      'location': 'Skin & Coat Vet Specialists (4.0 mi)',
      'availableSlot': 'Tomorrow, 02:30 PM',
      'avatarColor': Colors.deepOrange,
      'bio':
          'Diagnoses and treats complex skin allergies, ear infections, and parasite care.',
    },
    {
      'id': 'doc-5',
      'name': 'Dr. Amanda Brooks, DVM',
      'specialty': 'Surgery',
      'rating': 4.9,
      'reviewsCount': 110,
      'experience': '14 yrs exp',
      'fee': '\$75',
      'location': 'Metropolitan Vet Hospital (5.2 mi)',
      'availableSlot': 'Thu, Sep 11, 11:00 AM',
      'avatarColor': Colors.indigo,
      'bio':
          'Board-certified soft tissue surgeon and orthopedic specialist for companion pets.',
    },
  ];

  // Booked appointments list
  final List<Map<String, dynamic>> _myAppointments = [
    {
      'doctorName': 'Dr. Sarah Jenkins, DVM',
      'specialty': 'General Vet',
      'petName': 'Max (Golden Retriever)',
      'date': 'Tomorrow, 03:00 PM',
      'type': 'In-Clinic Visit',
      'status': 'Confirmed',
      'location': 'City Pet Clinic, Downtown',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showEmergencyHotlineDialog() {
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
                color: PawStayTheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emergency_rounded,
                color: PawStayTheme.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '24/7 Vet Hotline',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'If your pet is experiencing a life-threatening medical emergency, call our immediate tele-vet responder line or visit the nearest ER center.',
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PawStayTheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(PawStayTheme.radiusDefault),
                border: Border.all(
                  color: PawStayTheme.error.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.phone_in_talk_rounded,
                    color: PawStayTheme.error,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergency Hotline:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: PawStayTheme.onErrorContainer,
                        ),
                      ),
                      Text(
                        '+1 (800) 555-PAW-ER',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: PawStayTheme.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: PawStayTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Connecting to emergency vet call operator...',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white),
                  ),
                  backgroundColor: PawStayTheme.error,
                ),
              );
            },
            icon: const Icon(Icons.call, size: 18),
            label: Text(
              'Call Now',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingModal(Map<String, dynamic> doctor) {
    String selectedPet = 'Max (Golden Retriever)';
    String consultationType = 'In-Clinic Visit';
    String selectedTime = 'Today, 03:00 PM';
    final reasonController = TextEditingController();

    final petsList = [
      'Max (Golden Retriever)',
      'Luna (Persian Cat)',
      'Bella (Beagle)',
      'Add New Pet...',
    ];

    final timeSlots = [
      'Today, 03:00 PM',
      'Today, 04:30 PM',
      'Tomorrow, 10:00 AM',
      'Tomorrow, 02:00 PM',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          return Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 24,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: doctor['avatarColor'] as Color,
                        radius: 20,
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doctor['name'],
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${doctor['specialty']} • ${doctor['fee']}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Select Pet
                  Text(
                    'Select Your Pet',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPet,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: petsList
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                              p,
                              style: GoogleFonts.plusJakartaSans(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedPet = val);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Consultation Type
                  Text(
                    'Consultation Type',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.location_on_rounded, size: 16),
                              SizedBox(width: 6),
                              Text('In-Clinic'),
                            ],
                          ),
                          selected: consultationType == 'In-Clinic Visit',
                          selectedColor: theme.colorScheme.primaryContainer,
                          onSelected: (sel) {
                            if (sel) {
                              setModalState(
                                () => consultationType = 'In-Clinic Visit',
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.videocam_rounded, size: 16),
                              SizedBox(width: 6),
                              Text('Video Call'),
                            ],
                          ),
                          selected: consultationType == 'Video Call',
                          selectedColor: theme.colorScheme.primaryContainer,
                          onSelected: (sel) {
                            if (sel) {
                              setModalState(
                                () => consultationType = 'Video Call',
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Time Slot
                  Text(
                    'Available Time Slots',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: timeSlots.map((slot) {
                      final isSel = selectedTime == slot;
                      return ChoiceChip(
                        label: Text(
                          slot,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSel,
                        selectedColor: PawStayTheme.secondaryContainer,
                        onSelected: (sel) {
                          if (sel) setModalState(() => selectedTime = slot);
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Reason text field
                  Text(
                    'Reason for Visit / Symptoms (Optional)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText:
                          'e.g. Routine checkup, loss of appetite, itching...',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Confirm Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _myAppointments.insert(0, {
                            'doctorName': doctor['name'],
                            'specialty': doctor['specialty'],
                            'petName': selectedPet,
                            'date': selectedTime,
                            'type': consultationType,
                            'status': 'Confirmed',
                            'location': doctor['location'],
                          });
                        });
                        Navigator.pop(ctx);

                        // Switch tab to My Appointments
                        _tabController.animateTo(1);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Appointment confirmed with ${doctor['name']}!',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: PawStayTheme.secondary,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Confirm Appointment (${doctor['fee']})',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredDoctors = _doctors.where((doc) {
      final matchesCategory =
          _selectedCategory == 'All' || doc['specialty'] == _selectedCategory;
      final query = _searchController.text.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          (doc['name'] as String).toLowerCase().contains(query) ||
          (doc['specialty'] as String).toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Doctor & Vet Care',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.emergency_rounded,
              color: PawStayTheme.error,
            ),
            tooltip: '24/7 Emergency Vet Hotline',
            onPressed: _showEmergencyHotlineDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.local_hospital_rounded), text: 'Find Vets'),
            Tab(icon: Icon(Icons.event_available_rounded), text: 'My Bookings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Find Vets
          SingleChildScrollView(
            padding: const EdgeInsets.all(PawStayTheme.marginMobile),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 24/7 Tele-Vet Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        PawStayTheme.errorContainer,
                        PawStayTheme.primaryContainer.withValues(alpha: 0.4),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
                    border: Border.all(
                      color: PawStayTheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.medical_services_rounded,
                          color: PawStayTheme.error,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instant Tele-Vet Consultation',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: PawStayTheme.onErrorContainer,
                              ),
                            ),
                            Text(
                              'Speak to a licensed vet in under 5 minutes',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: PawStayTheme.onErrorContainer.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PawStayTheme.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        onPressed: _showEmergencyHotlineDialog,
                        child: Text(
                          'Call Now',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search vet name or specialty...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 16),

                // Category Chips
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category;
                      return ChoiceChip(
                        label: Text(
                          category,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
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
                          if (sel) setState(() => _selectedCategory = category);
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Top Veterinary Specialists (${filteredDoctors.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Doctors List
                filteredDoctors.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No doctors found matching criteria.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredDoctors.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final doc = filteredDoctors[index];
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                PawStayTheme.radiusMd,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor:
                                            doc['avatarColor'] as Color,
                                        child: Text(
                                          (doc['name'] as String)
                                              .replaceAll('Dr. ', '')
                                              .substring(0, 1),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              doc['name'],
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${doc['specialty']} • ${doc['experience']}',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 13,
                                                    color: theme
                                                        .colorScheme
                                                        .primary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.star_rounded,
                                                  color: Colors.amber,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${doc['rating']} (${doc['reviewsCount']} reviews)',
                                                  style:
                                                      GoogleFonts.plusJakartaSans(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  doc['fee'],
                                                  style:
                                                      GoogleFonts.plusJakartaSans(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: PawStayTheme
                                                            .secondary,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    doc['bio'],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 16,
                                        color: theme.colorScheme.outline,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          doc['location'],
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: theme.colorScheme.outline,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time_rounded,
                                        size: 16,
                                        color: PawStayTheme.secondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Next Slot: ${doc['availableSlot']}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: PawStayTheme.secondary,
                                        ),
                                      ),
                                      const Spacer(),
                                      ElevatedButton(
                                        onPressed: () => _showBookingModal(doc),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                        ),
                                        child: Text(
                                          'Book Visit',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),

          // TAB 2: My Bookings
          _myAppointments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No upcoming appointments yet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Book a consultation with our verified doctors!',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(PawStayTheme.marginMobile),
                  itemCount: _myAppointments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final appt = _myAppointments[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          PawStayTheme.radiusMd,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: PawStayTheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.event_available_rounded,
                                    color: PawStayTheme.onSecondaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        appt['doctorName'],
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'For: ${appt['petName']}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: PawStayTheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    appt['status'],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: PawStayTheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  appt['date'],
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(
                                    appt['type'],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
