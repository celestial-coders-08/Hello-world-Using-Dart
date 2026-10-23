import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../theme/pawstay_theme.dart';
import '../user/chat_detail_screen.dart';

class ProviderBookingsScreen extends StatefulWidget {
  final String? providerLookup;
  final int initialTabIndex;

  const ProviderBookingsScreen({
    super.key,
    this.providerLookup,
    this.initialTabIndex = 0,
  });

  @override
  State<ProviderBookingsScreen> createState() => _ProviderBookingsScreenState();
}

class _ProviderBookingsScreenState extends State<ProviderBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isScheduleView = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allBookings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final bookings = await ApiService.fetchProviderBookings(
      providerLookup: widget.providerLookup,
    );
    if (!mounted) return;
    setState(() {
      _allBookings = bookings;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _filterBookings(String tabKey) {
    switch (tabKey) {
      case 'requests':
        return _allBookings
            .where((b) => (b['status'] ?? '').toString().toLowerCase() == 'pending')
            .toList();
      case 'upcoming':
        return _allBookings
            .where((b) => (b['status'] ?? '').toString().toLowerCase() == 'accepted')
            .toList();
      case 'completed':
        return _allBookings
            .where((b) => (b['status'] ?? '').toString().toLowerCase() == 'completed')
            .toList();
      case 'cancelled':
        return _allBookings.where((b) {
          final s = (b['status'] ?? '').toString().toLowerCase();
          return s == 'declined' || s == 'cancelled';
        }).toList();
      default:
        return _allBookings;
    }
  }

  static const _shortWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _fullWeekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _fullMonths = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  String _formatDateTime(String? dtStr) {
    if (dtStr == null || dtStr.trim().isEmpty) return 'Date TBD';
    try {
      final dt = DateTime.parse(dtStr);
      final weekday = _shortWeekdays[dt.weekday - 1];
      final month = _shortMonths[dt.month - 1];
      final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$weekday, $month ${dt.day}, ${dt.year} • $hour12:$minute $ampm';
    } catch (_) {
      return dtStr;
    }
  }

  String _formatDateOnly(String? dtStr) {
    if (dtStr == null || dtStr.trim().isEmpty) return 'Date TBD';
    try {
      final dt = DateTime.parse(dtStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final bookingDate = DateTime(dt.year, dt.month, dt.day);
      final diffDays = bookingDate.difference(today).inDays;
      final shortMonth = _shortMonths[dt.month - 1];

      if (diffDays == 0) return 'Today, $shortMonth ${dt.day}';
      if (diffDays == 1) return 'Tomorrow, $shortMonth ${dt.day}';
      final fullDay = _fullWeekdays[dt.weekday - 1];
      final fullMonth = _fullMonths[dt.month - 1];
      return '$fullDay, $fullMonth ${dt.day}, ${dt.year}';
    } catch (_) {
      return dtStr;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFFF3E0);
      case 'accepted':
        return const Color(0xFFE8F5E9);
      case 'completed':
        return const Color(0xFFE3F2FD);
      case 'declined':
      case 'cancelled':
        return const Color(0xFFFFEBEE);
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFE65100);
      case 'accepted':
        return const Color(0xFF2E7D32);
      case 'completed':
        return const Color(0xFF1565C0);
      case 'declined':
      case 'cancelled':
        return const Color(0xFFC62828);
      default:
        return Colors.grey.shade800;
    }
  }

  void _openBookingDetail(int bookingId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingDetailScreen(
          bookingId: bookingId,
          providerLookup: widget.providerLookup,
        ),
      ),
    ).then((_) => _loadBookings());
  }

  Widget _buildStatusChip(String status) {
    final cap = status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusBgColor(status),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusTextColor(status).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        cap,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: _getStatusTextColor(status),
        ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final id = (booking['id'] as num?)?.toInt() ?? 0;
    final customerName = booking['customer_name']?.toString() ?? 'Customer';
    final serviceName = booking['service_name']?.toString() ??
        (booking['service_type'] == 'package' ? 'Package Service' : 'Pet Sitter');
    final petName = booking['pet_name']?.toString() ?? 'Pet';
    final petType = booking['pet_type']?.toString() ?? 'Dog';
    final price = (booking['price_snapshot'] as num?)?.toDouble() ?? 0.0;
    final startDt = booking['start_datetime']?.toString();
    final status = (booking['status']?.toString() ?? 'pending').toLowerCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E5DF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openBookingDetail(id),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: PawStayTheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            serviceName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: PawStayTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildStatusChip(status),
                        const SizedBox(height: 4),
                        Text(
                          '₹${price.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: PawStayTheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF5EBE6)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: Color(0xFF8C7A74),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formatDateTime(startDt),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF6E5D57),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8EDE8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pets, size: 12, color: PawStayTheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '$petName ($petType)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: PawStayTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: PawStayTheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: PawStayTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: PawStayTheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: PawStayTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabList(String tabKey, String emptyTitle, String emptySubtitle, IconData emptyIcon) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: PawStayTheme.primary));
    }

    final items = _filterBookings(tabKey);
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadBookings,
        color: PawStayTheme.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: _buildEmptyState(emptyTitle, emptySubtitle, emptyIcon),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      color: PawStayTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildBookingCard(items[index]),
      ),
    );
  }

  Widget _buildScheduleTimeline() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: PawStayTheme.primary));
    }

    // Filter accepted / upcoming bookings and group by date
    final upcoming = _filterBookings('upcoming');
    if (upcoming.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadBookings,
        color: PawStayTheme.primary,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildEmptyState(
                'No Upcoming Schedule',
                'Accepted bookings will be neatly arranged by date here so you can plan your day.',
                Icons.calendar_month_rounded,
              ),
            ),
          ],
        ),
      );
    }

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final b in upcoming) {
      final dateKey = _formatDateOnly(b['start_datetime']?.toString());
      grouped.putIfAbsent(dateKey, () => []).add(b);
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      color: PawStayTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: grouped.keys.length,
        itemBuilder: (context, index) {
          final dateHeader = grouped.keys.elementAt(index);
          final dayBookings = grouped[dateHeader]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: PawStayTheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateHeader,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: PawStayTheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E7E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${dayBookings.length} stay${dayBookings.length > 1 ? 's' : ''}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: PawStayTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...dayBookings.map(_buildBookingCard),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: PawStayTheme.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isScheduleView ? 'Service Schedule' : 'Bookings',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: PawStayTheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _isScheduleView ? 'Tabs View' : 'Schedule View',
            icon: Icon(
              _isScheduleView ? Icons.view_agenda_outlined : Icons.calendar_month_rounded,
              color: PawStayTheme.primary,
            ),
            onPressed: () {
              setState(() => _isScheduleView = !_isScheduleView);
            },
          ),
        ],
        bottom: _isScheduleView
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: PawStayTheme.primary,
                unselectedLabelColor: PawStayTheme.onSurfaceVariant,
                indicatorColor: PawStayTheme.primary,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'Requests'),
                  Tab(text: 'Upcoming'),
                  Tab(text: 'Completed'),
                  Tab(text: 'Cancelled'),
                ],
              ),
      ),
      body: _isScheduleView
          ? _buildScheduleTimeline()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTabList(
                  'requests',
                  'No Booking Requests',
                  'When clients request a pet sitter or care package, they will appear here for confirmation.',
                  Icons.inbox_rounded,
                ),
                _buildTabList(
                  'upcoming',
                  'No Upcoming Bookings',
                  'Confirmed and accepted bookings will appear here.',
                  Icons.event_available_rounded,
                ),
                _buildTabList(
                  'completed',
                  'No Completed Bookings',
                  'Your successfully finished pet sitting bookings will be archived here.',
                  Icons.check_circle_outline_rounded,
                ),
                _buildTabList(
                  'cancelled',
                  'No Cancelled Bookings',
                  'Declined or cancelled bookings will show here.',
                  Icons.highlight_off_rounded,
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Booking Detail Screen
// ---------------------------------------------------------------------------
class BookingDetailScreen extends StatefulWidget {
  final int bookingId;
  final String? providerLookup;

  const BookingDetailScreen({
    super.key,
    required this.bookingId,
    this.providerLookup,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  bool _isLoading = true;
  bool _isActionInProgress = false;
  Map<String, dynamic>? _booking;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final data = await ApiService.fetchBookingDetail(
      widget.bookingId,
      providerLookup: widget.providerLookup,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (data != null) {
        _booking = data;
      } else {
        _errorMessage = 'Booking details could not be found.';
      }
    });
  }

  Future<void> _updateStatus(String targetStatus) async {
    final statusLabel = targetStatus == 'accepted'
        ? 'Accept'
        : (targetStatus == 'declined' ? 'Decline' : 'Mark Completed');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '$statusLabel Booking?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to $statusLabel this booking request?',
          style: GoogleFonts.plusJakartaSans(color: PawStayTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade700),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: targetStatus == 'declined'
                  ? const Color(0xFFC62828)
                  : PawStayTheme.primary,
            ),
            child: Text(
              'Confirm',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionInProgress = true);
    final success = await ApiService.updateBookingStatus(
      widget.bookingId,
      targetStatus,
      providerLookup: widget.providerLookup,
    );

    if (!mounted) return;
    setState(() => _isActionInProgress = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Booking successfully updated to ${targetStatus.toUpperCase()}.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          backgroundColor: targetStatus == 'declined'
              ? const Color(0xFFC62828)
              : PawStayTheme.secondary,
        ),
      );
      _fetchDetail();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update booking status. Please try again.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          backgroundColor: PawStayTheme.error,
        ),
      );
    }
  }

  Future<void> _chatWithCustomer() async {
    if (_booking == null) return;
    final customerId = _booking!['customer_id']?.toString() ?? '';
    final customerName = _booking!['customer_name']?.toString() ?? 'Customer';
    final providerId = widget.providerLookup?.trim() ?? 'provider';

    if (customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Customer contact information is unavailable.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          backgroundColor: PawStayTheme.error,
        ),
      );
      return;
    }

    setState(() => _isActionInProgress = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.messageBaseUrl}/conversations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': providerId,
          'contact_id': customerId,
          'contact_name': customerName,
          'contact_avatar_url': null,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Could not start conversation');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final conversationId = (data['id'] as num).toInt();

      if (!mounted) return;
      setState(() => _isActionInProgress = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            conversationId: conversationId,
            contactName: customerName,
            userId: providerId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionInProgress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to start chat with customer. Please verify message server.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          backgroundColor: PawStayTheme.error,
        ),
      );
    }
  }

  String _formatDateTime(String? dtStr) {
    if (dtStr == null || dtStr.trim().isEmpty) return 'Date TBD';
    try {
      final dt = DateTime.parse(dtStr);
      const shortWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final weekday = shortWeekdays[dt.weekday - 1];
      final month = shortMonths[dt.month - 1];
      final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$weekday, $month ${dt.day}, ${dt.year} • $hour12:$minute $ampm';
    } catch (_) {
      return dtStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: PawStayTheme.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Booking #${widget.bookingId}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: PawStayTheme.onSurface,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: PawStayTheme.primary))
          : (_errorMessage != null || _booking == null)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage ?? 'No details available',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchDetail,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildContent(),
      bottomNavigationBar: _booking == null || _isLoading ? null : _buildBottomActionBar(),
    );
  }

  Widget _buildContent() {
    final customerName = _booking!['customer_name']?.toString() ?? 'Customer';
    final serviceName = _booking!['service_name']?.toString() ??
        (_booking!['service_type'] == 'package' ? 'Package Service' : 'Pet Sitter');
    final petName = _booking!['pet_name']?.toString() ?? 'Pet';
    final petType = _booking!['pet_type']?.toString() ?? 'Dog';
    final notes = _booking!['notes']?.toString() ?? '';
    final price = (_booking!['price_snapshot'] as num?)?.toDouble() ?? 0.0;
    final startDt = _booking!['start_datetime']?.toString();
    final endDt = _booking!['end_datetime']?.toString();
    final status = (_booking!['status']?.toString() ?? 'pending').toLowerCase();
    final createdAt = _booking!['created_at']?.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF0E5DF)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      serviceName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: PawStayTheme.onSurface,
                      ),
                    ),
                    _buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${price.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: PawStayTheme.primary,
                  ),
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Booked on ${_formatDateTime(createdAt)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: PawStayTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Schedule Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0E5DF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_note_rounded, size: 20, color: PawStayTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Schedule Timeframe',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: PawStayTheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildInfoRow('Start Date & Time', _formatDateTime(startDt)),
                const SizedBox(height: 10),
                _buildInfoRow('End Date & Time', _formatDateTime(endDt)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Customer & Pet Information
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0E5DF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_rounded, size: 20, color: PawStayTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Client & Pet Information',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: PawStayTheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildInfoRow('Client Name', customerName),
                const SizedBox(height: 10),
                _buildInfoRow('Pet Name', petName),
                const SizedBox(height: 10),
                _buildInfoRow('Pet Type', petType),
                const SizedBox(height: 10),
                _buildInfoRow('Special Notes', notes.isNotEmpty ? notes : 'None provided'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Chat Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isActionInProgress ? null : _chatWithCustomer,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: Text(
                'Chat with $customerName',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: PawStayTheme.primary,
                side: const BorderSide(color: PawStayTheme.primary, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 125,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PawStayTheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: PawStayTheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    final cap = status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : status;
    Color bg = const Color(0xFFFFF3E0);
    Color txt = const Color(0xFFE65100);

    if (status == 'accepted') {
      bg = const Color(0xFFE8F5E9);
      txt = const Color(0xFF2E7D32);
    } else if (status == 'completed') {
      bg = const Color(0xFFE3F2FD);
      txt = const Color(0xFF1565C0);
    } else if (status == 'declined' || status == 'cancelled') {
      bg = const Color(0xFFFFEBEE);
      txt = const Color(0xFFC62828);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        cap,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: txt,
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final status = (_booking!['status']?.toString() ?? 'pending').toLowerCase();

    if (status == 'pending') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -4),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isActionInProgress ? null : () => _updateStatus('declined'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC62828),
                    side: const BorderSide(color: Color(0xFFEF9A9A)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Decline',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _isActionInProgress ? null : () => _updateStatus('accepted'),
                  style: FilledButton.styleFrom(
                    backgroundColor: PawStayTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isActionInProgress
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Accept Booking',
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
    } else if (status == 'accepted') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -4),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isActionInProgress ? null : () => _updateStatus('completed'),
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(
                'Mark as Completed',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
