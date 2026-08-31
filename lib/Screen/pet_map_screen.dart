import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../theme/pawstay_theme.dart';

// ─── Constants ───────────────────────────────────────────────────────────────
const String _mapsApiKey = 'Google_MAP_API';

// Places Nearby Search radius in meters
const int _searchRadius = 3000;

// ─── Service Category Model ───────────────────────────────────────────────────
class ServiceCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  /// Google Places API type keyword for Places Nearby Search
  final String placesType;

  const ServiceCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.placesType,
  });
}

const List<ServiceCategory> _serviceCategories = [
  ServiceCategory(
    id: 'all',
    label: 'Nearby',
    icon: Icons.location_on_rounded,
    color: PawStayTheme.primary,
    placesType: 'veterinary_care',
  ),
  ServiceCategory(
    id: 'doctor',
    label: 'Pet Doctor',
    icon: Icons.medical_services_rounded,
    color: Color(0xFFBA1A1A),
    placesType: 'veterinary_care',
  ),
  ServiceCategory(
    id: 'grooming',
    label: 'Pet Grooming',
    icon: Icons.content_cut_rounded,
    color: Color(0xFFD97757),
    placesType: 'pet_store',
  ),
  ServiceCategory(
    id: 'food',
    label: 'Pet Food',
    icon: Icons.restaurant_rounded,
    color: Color(0xFF99462A),
    placesType: 'pet_store',
  ),
  ServiceCategory(
    id: 'sell',
    label: 'Pet Store',
    icon: Icons.shopping_bag_rounded,
    color: Color(0xFF506447),
    placesType: 'pet_store',
  ),
  ServiceCategory(
    id: 'emergency',
    label: 'Emergency',
    icon: Icons.emergency_rounded,
    color: Color(0xFFBA1A1A),
    placesType: 'veterinary_care',
  ),
];

// ─── Pet Service Place Model ──────────────────────────────────────────────────
class PetServicePlace {
  final String id;
  final String name;
  final String categoryId;
  final LatLng position;
  final double rating;
  final String distance;
  final String openStatus;
  final String? address;
  final String? placeId;

  PetServicePlace({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.position,
    required this.rating,
    required this.distance,
    required this.openStatus,
    this.address,
    this.placeId,
  });

  factory PetServicePlace.fromPlacesResult(
    Map<String, dynamic> result,
    String categoryId,
    LatLng userLocation,
  ) {
    final loc = result['geometry']['location'];
    final pos = LatLng(
      (loc['lat'] as num).toDouble(),
      (loc['lng'] as num).toDouble(),
    );

    final rating = (result['rating'] as num?)?.toDouble() ?? 0.0;
    final isOpen = result['opening_hours']?['open_now'];
    final openStatus = isOpen == null
        ? 'Hours unknown'
        : (isOpen ? 'Open now' : 'Closed');

    // Compute straight-line distance
    final distM = _haversineDistance(userLocation, pos);
    final distLabel = distM < 1000
        ? '${distM.toInt()} m'
        : '${(distM / 1000).toStringAsFixed(1)} km';

    return PetServicePlace(
      id: result['place_id'] as String,
      name: result['name'] as String,
      categoryId: categoryId,
      position: pos,
      rating: rating,
      distance: distLabel,
      openStatus: openStatus,
      address: result['vicinity'] as String?,
      placeId: result['place_id'] as String,
    );
  }
}

double _haversineDistance(LatLng a, LatLng b) {
  const r = 6371000.0;
  final phi1 = a.latitude * math.pi / 180;
  final phi2 = b.latitude * math.pi / 180;
  final dPhi = (b.latitude - a.latitude) * math.pi / 180;
  final dLambda = (b.longitude - a.longitude) * math.pi / 180;
  final sinDPhi = math.sin(dPhi / 2);
  final sinDLambda = math.sin(dLambda / 2);
  final aSq =
      sinDPhi * sinDPhi +
      math.cos(phi1) * math.cos(phi2) * sinDLambda * sinDLambda;
  return r * 2 * math.atan2(math.sqrt(aSq), math.sqrt(1 - aSq));
}

// ─── Navigation Step Model ────────────────────────────────────────────────────
class NavStep {
  final String instruction;
  final String distance;
  final String duration;
  final LatLng startLocation;
  NavStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.startLocation,
  });
}

// ─── Screen State ─────────────────────────────────────────────────────────────
class PetMapScreen extends StatefulWidget {
  const PetMapScreen({super.key});

  @override
  State<PetMapScreen> createState() => _PetMapScreenState();
}

class _PetMapScreenState extends State<PetMapScreen>
    with TickerProviderStateMixin {
  // Map controller
  final Completer<GoogleMapController> _mapController = Completer();
  LatLng? _currentPosition;
  bool _isLoadingLocation = true;
  String _locationError = '';

  // Filter state
  String _selectedCategoryId = 'all';
  bool _isLoadingPlaces = false;

  // Selected place
  PetServicePlace? _selectedPlace;
  bool _isRouting = false;
  List<LatLng> _routePoints = [];

  // Markers
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<Marker> _trailMarkers = [];
  BitmapDescriptor? _pawIcon;

  // Paw pulse animation (for loading / header badge)
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Navigation paw trail animation
  late AnimationController _pawTrailController;
  int _pawStep = 0;

  // Real places from Places API
  List<PetServicePlace> _allPlaces = [];

  // Navigation state
  bool _isNavigating = false;
  NavStep? _currentNavStep;
  String _remainingDistance = '';
  String _remainingDuration = '';
  List<NavStep> _navSteps = [];

  Timer? _routeAnimationTimer;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pawTrailController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 600),
        )..addStatusListener((s) {
          if (s == AnimationStatus.completed && _isNavigating) {
            setState(() => _pawStep = (_pawStep + 1) % 4);
            _pawTrailController.reset();
            _pawTrailController.forward();
          }
        });

    _loadPawIcon();
    _initLocation();
  }

  Future<void> _loadPawIcon() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.pets.codePoint),
      style: TextStyle(
        fontSize: 32.0,
        fontFamily: Icons.pets.fontFamily,
        color: PawStayTheme.primary,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(0.0, 0.0));

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      textPainter.width.toInt(),
      textPainter.height.toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData != null) {
      _pawIcon = BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pawTrailController.dispose();
    _routeAnimationTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  // ─── Location ──────────────────────────────────────────────────────────────
  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationError =
                'Location services are disabled. Please enable GPS.';
            _isLoadingLocation = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _locationError =
                  'Location permission denied. Please allow location access.';
              _isLoadingLocation = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationError =
                'Location permission permanently denied. Please enable it in Settings.';
            _isLoadingLocation = false;
          });
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final latLng = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _currentPosition = latLng;
          _isLoadingLocation = false;
        });
      }

      // Fetch real places from Google Places Nearby Search
      await _fetchNearbyPlaces(latLng, _selectedCategoryId);
      _buildMarkers();

      // Animate camera to user
      if (_mapController.isCompleted) {
        final controller = await _mapController.future;
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: latLng, zoom: 15.0),
          ),
        );
      }

      // Start live position tracking
      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10, // update every 10m
            ),
          ).listen((Position position) {
            if (!mounted) return;
            final newPos = LatLng(position.latitude, position.longitude);
            setState(() {
              _currentPosition = newPos;
            });
            _buildMarkers();

            // While navigating: re-fetch route and update nav step
            if (_isNavigating && _selectedPlace != null) {
              _updateNavigationProgress(newPos);
            }
          });
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Could not get location: ${e.toString()}';
          _isLoadingLocation = false;
        });
      }
    }
  }

  // ─── Google Places Nearby Search & Custom KML ─────────────────────────────
  Future<void> _fetchNearbyPlaces(LatLng center, String categoryId) async {
    if (mounted) setState(() => _isLoadingPlaces = true);

    final List<PetServicePlace> results = [];
    final seenIds = <String>{};

    // 1. Fetch Custom KML Points
    try {
      final response = await http.get(
        Uri.parse(
          'https://www.google.com/maps/d/kml?mid=1CYuAvYG-d-ZeSw4kq61QOoTvHFsUK1s&forcekml=1',
        ),
      );
      if (response.statusCode == 200) {
        final String kml = utf8.decode(response.bodyBytes);
        final placemarkExp = RegExp(
          r'<Placemark>(.*?)</Placemark>',
          dotAll: true,
        );
        final nameExp = RegExp(r'<name>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</name>');
        final coordExp = RegExp(
          r'<coordinates>\s*([^,]+),([^,]+),[^<]*</coordinates>',
        );

        for (final m in placemarkExp.allMatches(kml)) {
          final block = m.group(1)!;
          final nameMatch = nameExp.firstMatch(block);
          final coordMatch = coordExp.firstMatch(block);

          if (nameMatch != null && coordMatch != null) {
            final name = nameMatch.group(1)!;
            final lng = double.tryParse(coordMatch.group(1)!.trim());
            final lat = double.tryParse(coordMatch.group(2)!.trim());

            if (lat != null && lng != null) {
              final pos = LatLng(lat, lng);
              final distM = _haversineDistance(center, pos);
              final distLabel = distM < 1000
                  ? '${distM.toInt()} m'
                  : '${(distM / 1000).toStringAsFixed(1)} km';

              final customId = 'kml_${name.hashCode}';

              String cat = 'sell';
              final lower = name.toLowerCase();
              if (lower.contains('hospital') ||
                  lower.contains('clinic') ||
                  lower.contains('vet') ||
                  lower.contains('dr')) {
                cat = 'doctor';
              } else if (lower.contains('food')) {
                cat = 'food';
              } else if (lower.contains('grooming') ||
                  lower.contains('spa') ||
                  lower.contains('parlor')) {
                cat = 'grooming';
              }

              if (seenIds.add(customId)) {
                results.add(
                  PetServicePlace(
                    id: customId,
                    name: name,
                    categoryId: cat,
                    position: pos,
                    rating: 5.0,
                    distance: distLabel,
                    openStatus: 'Featured',
                    address: 'Custom Map Location',
                    placeId: null,
                  ),
                );
              }
            }
          }
        }
      }
    } catch (_) {}

    // 2. Collect types to search for Places API
    final categories = categoryId == 'all'
        ? _serviceCategories.where((c) => c.id != 'all').toList()
        : _serviceCategories.where((c) => c.id == categoryId).toList();

    // Deduplicate by placesType
    final seenTypes = <String>{};
    final toFetch = categories
        .where((c) => seenTypes.add(c.placesType))
        .toList();

    for (final cat in toFetch) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=${center.latitude},${center.longitude}'
          '&radius=$_searchRadius'
          '&type=${cat.placesType}'
          '&key=$_mapsApiKey',
        );

        final response = await http
            .get(url)
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'OK' || data['status'] == 'ZERO_RESULTS') {
            for (final r in (data['results'] as List).take(10)) {
              final id = r['place_id'] as String;
              if (seenIds.add(id)) {
                // Map to best category label
                final matchingCat = categoryId == 'all' ? cat : cat;
                results.add(
                  PetServicePlace.fromPlacesResult(
                    r as Map<String, dynamic>,
                    matchingCat.id == 'all' ? cat.id : categoryId,
                    center,
                  ),
                );
              }
            }
          }
        }
      } catch (_) {
        // Skip this type on error
      }
    }

    if (mounted) {
      setState(() {
        _allPlaces = results;
        _isLoadingPlaces = false;
      });
    }
  }

  double _getHueForCategory(String categoryId) {
    switch (categoryId) {
      case 'doctor':
      case 'emergency':
        return BitmapDescriptor.hueRed;
      case 'sell':
        return BitmapDescriptor.hueGreen;
      case 'food':
        return BitmapDescriptor.hueOrange;
      case 'grooming':
        return BitmapDescriptor.hueMagenta;
      default:
        return BitmapDescriptor.hueViolet;
    }
  }

  void _buildMarkers() {
    final filtered = _selectedCategoryId == 'all'
        ? _allPlaces
        : _allPlaces.where((p) => p.categoryId == _selectedCategoryId).toList();

    setState(() {
      _markers = filtered.map((place) {
        final isSelected = _selectedPlace?.id == place.id;
        return Marker(
          markerId: MarkerId(place.id),
          position: place.position,
          onTap: () => _onMarkerTap(place),
          icon: isSelected
              ? BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueYellow,
                )
              : BitmapDescriptor.defaultMarkerWithHue(
                  _getHueForCategory(place.categoryId),
                ),
          infoWindow: InfoWindow(
            title: place.name,
            snippet: place.rating > 0
                ? '${place.rating.toStringAsFixed(1)}★ · ${place.distance}'
                : place.distance,
          ),
        );
      }).toSet();

      // User location = BLUE marker
      if (_currentPosition != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('my_location'),
            position: _currentPosition!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: const InfoWindow(title: 'You are here'),
          ),
        );
      }

      _markers.addAll(_trailMarkers);
    });
  }

  void _onMarkerTap(PetServicePlace place) {
    setState(() {
      _selectedPlace = place;
    });
    _buildMarkers();
    _showPlaceBottomSheet(place);
  }

  Future<void> _fetchRoute(PetServicePlace destination) async {
    if (_currentPosition == null) return;
    setState(() {
      _isRouting = true;
      _routePoints = [];
      _polylines = {};
      _trailMarkers = [];
      _navSteps = [];
      _currentNavStep = null;
    });

    final origin =
        '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    final dest =
        '${destination.position.latitude},${destination.position.longitude}';

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$origin&destination=$dest&mode=driving&key=$_mapsApiKey',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'OK') {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          // Decode overview polyline
          final points = route['overview_polyline']['points'] as String;
          final decoded = _decodePolyline(points);

          // Parse nav steps
          final rawSteps = leg['steps'] as List;
          _navSteps = rawSteps.map((s) {
            final loc = s['start_location'];
            return NavStep(
              instruction: _stripHtml(s['html_instructions'] as String),
              distance: s['distance']['text'] as String,
              duration: s['duration']['text'] as String,
              startLocation: LatLng(
                (loc['lat'] as num).toDouble(),
                (loc['lng'] as num).toDouble(),
              ),
            );
          }).toList();

          final totalDist = leg['distance']['text'] as String;
          final totalDur = leg['duration']['text'] as String;

          // Generate paw markers along the path
          final List<Marker> pawMarkers = [];
          if (_pawIcon != null) {
            double interval = 60.0; // Place a paw every 60 meters
            double accumulatedDistance = 0.0;

            for (int i = 0; i < decoded.length - 1; i++) {
              final p1 = decoded[i];
              final p2 = decoded[i + 1];
              final segmentDist = _haversineDistance(p1, p2);

              while (accumulatedDistance + segmentDist >= interval) {
                double ratio = (interval - accumulatedDistance) / segmentDist;
                final double lat =
                    p1.latitude + (p2.latitude - p1.latitude) * ratio;
                final double lng =
                    p1.longitude + (p2.longitude - p1.longitude) * ratio;
                final pos = LatLng(lat, lng);

                pawMarkers.add(
                  Marker(
                    markerId: MarkerId('paw_$i\_$ratio'),
                    position: pos,
                    icon: _pawIcon!,
                    anchor: const Offset(0.5, 0.5),
                  ),
                );

                accumulatedDistance -= interval;
              }
              accumulatedDistance += segmentDist;
            }
          }

          setState(() {
            _routePoints = decoded;
            _trailMarkers = pawMarkers;
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                points: decoded,
                color: PawStayTheme.primary.withValues(
                  alpha: 0.3,
                ), // Make line lighter so paws stand out
                width: 4,
                jointType: JointType.round,
                endCap: Cap.roundCap,
                startCap: Cap.roundCap,
              ),
            };
            _remainingDistance = totalDist;
            _remainingDuration = totalDur;
            _isNavigating = true;
            _currentNavStep = _navSteps.isNotEmpty ? _navSteps.first : null;
          });

          // Start paw trail animation
          _pawStep = 0;
          _pawTrailController.forward();

          // Fit camera to entire route
          final controller = await _mapController.future;
          final bounds = _boundsFromLatLngList([
            _currentPosition!,
            destination.position,
            ...decoded,
          ]);
          controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
        } else {
          _showNoRouteError();
        }
      }
    } catch (_) {
      _showNoRouteError();
    } finally {
      if (mounted) setState(() => _isRouting = false);
      _buildMarkers(); // Re-build to include new paw markers
    }
  }

  void _showNoRouteError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "No driving route found for this location. Google Maps Directions API couldn't generate a path.",
        ),
        backgroundColor: PawStayTheme.error,
      ),
    );
  }

  /// Strip HTML tags from Directions step instructions
  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]+>'), ' ').trim();
  }

  /// Update navigation progress as the user moves
  void _updateNavigationProgress(LatLng userPos) {
    if (_navSteps.isEmpty) return;

    // Find nearest upcoming step
    int nearestIdx = 0;
    double minDist = double.infinity;
    for (int i = 0; i < _navSteps.length; i++) {
      final d = _haversineDistance(userPos, _navSteps[i].startLocation);
      if (d < minDist) {
        minDist = d;
        nearestIdx = i;
      }
    }

    // Update remaining distance
    if (mounted) {
      setState(() {
        _currentNavStep = nearestIdx < _navSteps.length
            ? _navSteps[nearestIdx]
            : _navSteps.last;
        // Recalculate remaining distance roughly
        if (_selectedPlace != null) {
          final rem = _haversineDistance(userPos, _selectedPlace!.position);
          _remainingDistance = rem < 1000
              ? '${rem.toInt()} m'
              : '${(rem / 1000).toStringAsFixed(1)} km';
        }
      });
    }
  }

  // Decode Google encoded polyline
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> result = [];
    int index = 0;
    int lat = 0, lng = 0;

    while (index < encoded.length) {
      int shift = 0, result1 = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result1 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result1 & 1) != 0 ? ~(result1 >> 1) : result1 >> 1;
      lat += dlat;

      shift = 0;
      result1 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result1 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result1 & 1) != 0 ? ~(result1 >> 1) : result1 >> 1;
      lng += dlng;

      result.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return result;
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in list) {
      if (minLat == null || p.latitude < minLat) minLat = p.latitude;
      if (maxLat == null || p.latitude > maxLat) maxLat = p.latitude;
      if (minLng == null || p.longitude < minLng) minLng = p.longitude;
      if (maxLng == null || p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  Future<void> _openNativeMaps(PetServicePlace dest) async {
    final lat = dest.position.latitude;
    final lng = dest.position.longitude;
    final name = Uri.encodeComponent(dest.name);
    // Deep link into Google Maps for turn-by-turn
    final googleUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$lat,$lng&destination_place_id=${dest.placeId ?? ''}'
      '&travelmode=driving',
    );
    if (await canLaunchUrl(googleUri)) {
      await launchUrl(googleUri, mode: LaunchMode.externalApplication);
    } else {
      final uri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($name)');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
  }

  void _stopNavigation() {
    _pawTrailController.stop();
    _routeAnimationTimer?.cancel();
    setState(() {
      _isNavigating = false;
      _routePoints = [];
      _polylines = {};
      _trailMarkers = [];
      _selectedPlace = null;
      _navSteps = [];
      _currentNavStep = null;
      _remainingDistance = '';
      _remainingDuration = '';
    });
    _buildMarkers();
  }

  // ─── Bottom Sheet ──────────────────────────────────────────────────────────
  void _showPlaceBottomSheet(PetServicePlace place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlaceBottomSheet(
        place: place,
        isRouting: _isRouting,
        onStartNavigation: () async {
          Navigator.pop(context);
          await _fetchRoute(place);
        },
        onOpenMaps: () {
          Navigator.pop(context);
          _openNativeMaps(place);
        },
      ),
    );
  }

  // ─── Recenter ─────────────────────────────────────────────────────────────
  Future<void> _recenterMap() async {
    if (_currentPosition == null) return;
    final ctrl = await _mapController.future;
    ctrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentPosition!, zoom: 15),
      ),
    );
  }

  // ─── Category filter change ─────────────────────────────────────────────────
  Future<void> _onCategoryChanged(String catId) async {
    if (_selectedCategoryId == catId) return;
    setState(() {
      _selectedCategoryId = catId;
      _allPlaces = [];
    });
    if (_currentPosition != null) {
      await _fetchNearbyPlaces(_currentPosition!, catId);
      _buildMarkers();
    }
  }

  // ─── Search dialog ─────────────────────────────────────────────────────────
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _SearchDialog(
        selectedId: _selectedCategoryId,
        onSelected: (catId) {
          _onCategoryChanged(catId);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PawStayTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: PawStayTheme.onSurfaceVariant,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Explore Nearby Services',
          style: GoogleFonts.plusJakartaSans(
            color: PawStayTheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Category filter chips ─────────────────────────────────────────
          Container(
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: _serviceCategories.map((cat) {
                  final isSelected = _selectedCategoryId == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _onCategoryChanged(cat.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? cat.color : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? cat.color
                                : PawStayTheme.outlineVariant,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: cat.color.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat.icon,
                              size: 15,
                              color: isSelected
                                  ? Colors.white
                                  : PawStayTheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat.label,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : PawStayTheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Map ───────────────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                if (_isLoadingLocation)
                  _buildLoadingOverlay()
                else if (_locationError.isNotEmpty)
                  _buildErrorOverlay()
                else
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target:
                          _currentPosition ?? const LatLng(20.5937, 78.9629),
                      zoom: 15,
                    ),
                    onMapCreated: (ctrl) {
                      if (!_mapController.isCompleted) {
                        _mapController.complete(ctrl);
                      }
                    },
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: false, // We draw our own blue marker
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    mapType: MapType.normal,
                    onTap: (_) {
                      if (!_isNavigating) {
                        setState(() => _selectedPlace = null);
                      }
                    },
                  ),

                // ── Places loading indicator ──────────────────────────────
                if (_isLoadingPlaces && !_isLoadingLocation)
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: PawStayTheme.ambientShadow1,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: PawStayTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Loading nearby places...',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: PawStayTheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Paw trail badge (top-center) when NOT navigating ──────
                if (!_isLoadingLocation &&
                    _locationError.isEmpty &&
                    !_isNavigating &&
                    !_isLoadingPlaces)
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _PawPulseWidget(
                        animation: _pulseAnimation,
                        label: _currentCategoryLabel(),
                      ),
                    ),
                  ),

                // ── Routing loading indicator ──────────────────────────────
                if (_isRouting)
                  Positioned(
                    top: 70,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: PawStayTheme.ambientShadow1,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: PawStayTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Calculating route...',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: PawStayTheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Live Navigation Bar (top) ──────────────────────────────
                if (_isNavigating && _currentNavStep != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _NavigationBar(
                      step: _currentNavStep!,
                      remainingDistance: _remainingDistance,
                      remainingDuration: _remainingDuration,
                      destinationName: _selectedPlace?.name ?? '',
                      pawStep: _pawStep,
                      onStop: _stopNavigation,
                      onOpenMaps: () {
                        if (_selectedPlace != null) {
                          _openNativeMaps(_selectedPlace!);
                        }
                      },
                    ),
                  ),

                // ── Recenter FAB ───────────────────────────────────────────
                if (!_isLoadingLocation && _locationError.isEmpty)
                  Positioned(
                    bottom: _isNavigating ? 24 : 24,
                    right: 16,
                    child: _buildMapFab(
                      Icons.my_location_rounded,
                      PawStayTheme.primary,
                      _recenterMap,
                      tooltip: 'My location',
                    ),
                  ),

                // ── Clear Route button ─────────────────────────────────────
                if (_routePoints.isNotEmpty && !_isRouting && !_isNavigating)
                  Positioned(
                    bottom: 24,
                    left: 16,
                    child: ElevatedButton.icon(
                      onPressed: _stopNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: PawStayTheme.onSurface,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: PawStayTheme.error,
                      ),
                      label: Text(
                        'Clear Route',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _currentCategoryLabel() {
    if (_selectedCategoryId == 'all') return 'All Pet Services Nearby';
    return _serviceCategories
        .firstWhere(
          (c) => c.id == _selectedCategoryId,
          orElse: () => _serviceCategories.first,
        )
        .label;
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: PawStayTheme.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: const Icon(
                Icons.pets,
                size: 64,
                color: PawStayTheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Finding your location...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: PawStayTheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please allow location access',
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

  Widget _buildErrorOverlay() {
    return Container(
      color: PawStayTheme.background,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_rounded,
              size: 64,
              color: PawStayTheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Location Required',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: PawStayTheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _locationError,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: PawStayTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoadingLocation = true;
                  _locationError = '';
                });
                _initLocation();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PawStayTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'Try Again',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapFab(
    IconData icon,
    Color color,
    VoidCallback onTap, {
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: PawStayTheme.ambientShadow2,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

// ─── Live Navigation Bar ──────────────────────────────────────────────────────
class _NavigationBar extends StatelessWidget {
  final NavStep step;
  final String remainingDistance;
  final String remainingDuration;
  final String destinationName;
  final int pawStep;
  final VoidCallback onStop;
  final VoidCallback onOpenMaps;

  const _NavigationBar({
    required this.step,
    required this.remainingDistance,
    required this.remainingDuration,
    required this.destinationName,
    required this.pawStep,
    required this.onStop,
    required this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: PawStayTheme.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: PawStayTheme.primary.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: instruction + stop button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Paw trail animation widget
              _PawTrailIndicator(pawStep: pawStep),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.instruction,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${step.distance} · ${step.duration}',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onStop,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Bottom row: total remaining + open in Google Maps
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'To: $destinationName',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$remainingDistance away · ~$remainingDuration',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onOpenMaps,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.navigation_rounded,
                        color: PawStayTheme.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Open Maps',
                        style: GoogleFonts.plusJakartaSans(
                          color: PawStayTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Paw Trail Indicator (animated paw steps during navigation) ────────────────
class _PawTrailIndicator extends StatelessWidget {
  final int pawStep;

  const _PawTrailIndicator({required this.pawStep});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 52,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (i) {
          final isActive = i == pawStep;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.pets,
              size: isActive ? 18 : 10,
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Paw Pulse Decorative Widget ─────────────────────────────────────────────
class _PawPulseWidget extends StatelessWidget {
  final Animation<double> animation;
  final String label;

  const _PawPulseWidget({required this.animation, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: PawStayTheme.ambientShadow1,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: animation,
            child: const Icon(
              Icons.pets,
              color: PawStayTheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: PawStayTheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Place Bottom Sheet ───────────────────────────────────────────────────────
class _PlaceBottomSheet extends StatelessWidget {
  final PetServicePlace place;
  final bool isRouting;
  final VoidCallback onStartNavigation;
  final VoidCallback onOpenMaps;

  const _PlaceBottomSheet({
    required this.place,
    required this.isRouting,
    required this.onStartNavigation,
    required this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PawStayTheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title row
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: PawStayTheme.primaryContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pets,
                  color: PawStayTheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: PawStayTheme.onSurface,
                      ),
                    ),
                    if (place.address != null)
                      Text(
                        place.address!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: PawStayTheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Info pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (place.rating > 0)
                _InfoPill(
                  icon: Icons.star_rounded,
                  text: place.rating.toStringAsFixed(1),
                  color: const Color(0xFFF6A623),
                ),
              _InfoPill(
                icon: Icons.directions_car_rounded,
                text: place.distance,
                color: PawStayTheme.primary,
              ),
              _InfoPill(
                icon: Icons.access_time_rounded,
                text: place.openStatus,
                color: place.openStatus.toLowerCase().startsWith('open')
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFBA1A1A),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Action buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isRouting ? null : onStartNavigation,
              icon: isRouting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.navigation_rounded, size: 18),
              label: Text(
                isRouting ? 'Getting route...' : 'Start Navigation',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PawStayTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenMaps,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(
                'Open in Google Maps',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Search dialog ────────────────────────────────────────────────────────────
class _SearchDialog extends StatelessWidget {
  final String selectedId;
  final ValueChanged<String> onSelected;

  const _SearchDialog({required this.selectedId, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Category',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: PawStayTheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ..._serviceCategories.map((cat) {
              final isSelected = selectedId == cat.id;
              return ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 18),
                ),
                title: Text(
                  cat.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? cat.color : PawStayTheme.onSurface,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded, color: cat.color)
                    : null,
                onTap: () => onSelected(cat.id),
              );
            }),
          ],
        ),
      ),
    );
  }
}
