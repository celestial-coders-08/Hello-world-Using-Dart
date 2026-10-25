import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../theme/pawstay_theme.dart';

const _osmUserAgent = 'PawStay/1.0 (pet services map)';
const _initialMapCenter = LatLng(16.7, 74.24);

enum _Endpoint { source, destination }

class _ServiceCategory {
  const _ServiceCategory({
    required this.id,
    required this.label,
    required this.color,
    required this.icon,
  });

  final String id;
  final String label;
  final Color color;
  final IconData icon;
}

const _categories = <_ServiceCategory>[
  _ServiceCategory(
    id: 'all',
    label: 'All',
    color: PawStayTheme.primary,
    icon: Icons.pets_rounded,
  ),
  _ServiceCategory(
    id: 'vet',
    label: 'Pet hospitals',
    color: Color(0xFFD84A4A),
    icon: Icons.medical_services_rounded,
  ),
  _ServiceCategory(
    id: 'food',
    label: 'Pet food',
    color: Color(0xFF438B57),
    icon: Icons.restaurant_rounded,
  ),
  _ServiceCategory(
    id: 'shop',
    label: 'Pet shops',
    color: Color(0xFF3979C6),
    icon: Icons.storefront_rounded,
  ),
  _ServiceCategory(
    id: 'grooming',
    label: 'Pet grooming',
    color: Color(0xFF8B55B5),
    icon: Icons.content_cut_rounded,
  ),
];

const _mappedServices = <_PetService>[
  _PetService(
    id: 'shop-1',
    name: 'The Pet Mansion',
    categoryId: 'shop',
    position: LatLng(16.7075947, 74.2412905),
    address: '',
  ),
  _PetService(
    id: 'shop-2',
    name:
        'Rio Pet Shop | Best Pet Shop in Kolhapur | Top Pet Food & Pet Care Store Near You',
    categoryId: 'shop',
    position: LatLng(16.6684848, 74.2705103),
    address: '',
  ),
  _PetService(
    id: 'shop-3',
    name: 'Sai Suraj Pet Shop & Aquarium',
    categoryId: 'shop',
    position: LatLng(16.6922665, 74.2753517),
    address: 'Grooming parlour',
  ),
  _PetService(
    id: 'shop-4',
    name: "PET'S KINGDOM",
    categoryId: 'shop',
    position: LatLng(16.7098199, 74.2394223),
    address: '',
  ),
  _PetService(
    id: 'shop-5',
    name: 'Golden Pets',
    categoryId: 'shop',
    position: LatLng(16.6935372, 74.2417635),
    address: '',
  ),
  _PetService(
    id: 'shop-6',
    name: 'Pet City Kolhapur',
    categoryId: 'shop',
    position: LatLng(16.6996166, 74.2410441),
    address: '',
  ),
  _PetService(
    id: 'shop-7',
    name: 'Fish Planet And Pet Shop',
    categoryId: 'shop',
    position: LatLng(16.689251, 74.2249559),
    address: '',
  ),
  _PetService(
    id: 'shop-8',
    name: 'Miracle Paws The Pets World kolhapur',
    categoryId: 'shop',
    position: LatLng(16.7127608, 74.2438647),
    address: '',
  ),
  _PetService(
    id: 'shop-9',
    name: 'Little Paws Pet Spa',
    categoryId: 'shop',
    position: LatLng(16.6947388, 74.2418961),
    address: '',
  ),
  _PetService(
    id: 'shop-10',
    name: 'AKIS PET MALL',
    categoryId: 'shop',
    position: LatLng(16.6936918, 74.2416431),
    address: '',
  ),
  _PetService(
    id: 'shop-11',
    name: 'Kings Dog Grooming Center',
    categoryId: 'shop',
    position: LatLng(16.705701, 74.2379159),
    address: '',
  ),
  _PetService(
    id: 'shop-12',
    name: 'Sai suraj Dog & Cat Grooming parlour & Spa',
    categoryId: 'shop',
    position: LatLng(16.693154, 74.2674548),
    address: '',
  ),
  _PetService(
    id: 'vet-1',
    name: 'Animal Hospital Kolhapur',
    categoryId: 'vet',
    position: LatLng(16.6857358, 74.2241367),
    address: '',
  ),
  _PetService(
    id: 'vet-2',
    name: 'Kanfe Globuz Pet Polyclinics',
    categoryId: 'vet',
    position: LatLng(16.704238, 74.2476959),
    address: '',
  ),
  _PetService(
    id: 'vet-3',
    name: "Anil Patil's Dog Clinic",
    categoryId: 'vet',
    position: LatLng(16.7023184, 74.2536623),
    address: '',
  ),
  _PetService(
    id: 'vet-4',
    name: 'Pets Clinic',
    categoryId: 'vet',
    position: LatLng(16.696037, 74.2453309),
    address: '',
  ),
  _PetService(
    id: 'vet-5',
    name: 'Pets Matter Animal Clinic',
    categoryId: 'vet',
    position: LatLng(16.691416, 74.245948),
    address: '',
  ),
  _PetService(
    id: 'vet-6',
    name: "WALVEKAR'S PET CARE CLINIC",
    categoryId: 'vet',
    position: LatLng(16.670997, 74.2276045),
    address: '',
  ),
  _PetService(
    id: 'vet-7',
    name: 'Little Paws Pet Spa',
    categoryId: 'vet',
    position: LatLng(16.6947388, 74.2418961),
    address: '',
  ),
  _PetService(
    id: 'vet-8',
    name: 'Synergy Pet clinic',
    categoryId: 'vet',
    position: LatLng(16.7131274, 74.2378335),
    address: '',
  ),
  _PetService(
    id: 'vet-9',
    name: 'Paanjar Pol (Cow Barn & Animal Hospital)',
    categoryId: 'vet',
    position: LatLng(16.6915936, 74.2400798),
    address: '',
  ),
  _PetService(
    id: 'vet-10',
    name: 'Dr. Girish Kulkarni Veterinary Surgeon',
    categoryId: 'vet',
    position: LatLng(16.6597911, 74.2509689),
    address: '',
  ),
  _PetService(
    id: 'grooming-1',
    name: 'Pet City Kolhapur',
    categoryId: 'grooming',
    position: LatLng(16.6996166, 74.2410441),
    address: '',
  ),
  _PetService(
    id: 'grooming-2',
    name: 'Miracle Paws The Pets World kolhapur',
    categoryId: 'grooming',
    position: LatLng(16.7127608, 74.2438647),
    address: '',
  ),
  _PetService(
    id: 'grooming-3',
    name: 'Kings Pet Mall',
    categoryId: 'grooming',
    position: LatLng(16.706735, 74.2407304),
    address: '',
  ),
  _PetService(
    id: 'grooming-4',
    name: 'pet day care centre',
    categoryId: 'grooming',
    position: LatLng(16.7056974, 74.2379105),
    address: '',
  ),
  _PetService(
    id: 'grooming-5',
    name: 'The Pet Mansion',
    categoryId: 'grooming',
    position: LatLng(16.7075947, 74.2412905),
    address: '',
  ),
  _PetService(
    id: 'grooming-6',
    name: 'Star Pet Shop & Parlor',
    categoryId: 'grooming',
    position: LatLng(16.6965082, 74.2434892),
    address: '',
  ),
  _PetService(
    id: 'grooming-7',
    name: 'Sai suraj Dog & Cat Grooming parlour & Spa',
    categoryId: 'grooming',
    position: LatLng(16.693154, 74.2674548),
    address: '',
  ),
  _PetService(
    id: 'grooming-8',
    name: 'Kings Dog Grooming Center',
    categoryId: 'grooming',
    position: LatLng(16.705701, 74.2379159),
    address: '',
  ),
  _PetService(
    id: 'grooming-9',
    name: 'AKIS PET MALL',
    categoryId: 'grooming',
    position: LatLng(16.6936918, 74.2416431),
    address: '',
  ),
  _PetService(
    id: 'grooming-10',
    name: 'Little Paws Pet Spa',
    categoryId: 'grooming',
    position: LatLng(16.6947388, 74.2418961),
    address: '',
  ),
  _PetService(
    id: 'food-1',
    name: 'JINI PET STORE',
    categoryId: 'food',
    position: LatLng(16.6902289, 74.2266361),
    address: '',
  ),
  _PetService(
    id: 'food-2',
    name:
        'Rio Pet Shop | Best Pet Shop in Kolhapur | Top Pet Food & Pet Care Store Near You',
    categoryId: 'food',
    position: LatLng(16.6684848, 74.2705103),
    address: '',
  ),
  _PetService(
    id: 'food-3',
    name: 'Pets Villa - Pet Shop in Kolhapur',
    categoryId: 'food',
    position: LatLng(16.6972217, 74.2439764),
    address: '',
  ),
  _PetService(
    id: 'food-4',
    name: 'Miracle Paws The Pets World kolhapur',
    categoryId: 'food',
    position: LatLng(16.7127608, 74.2438647),
    address: '',
  ),
  _PetService(
    id: 'food-5',
    name: 'Pet City Kolhapur',
    categoryId: 'food',
    position: LatLng(16.6996166, 74.2410441),
    address: '',
  ),
  _PetService(
    id: 'food-6',
    name: 'The Pet Mansion',
    categoryId: 'food',
    position: LatLng(16.7075947, 74.2412905),
    address: '',
  ),
  _PetService(
    id: 'food-7',
    name: 'Golden Pets',
    categoryId: 'food',
    position: LatLng(16.6935372, 74.2417635),
    address: '',
  ),
  _PetService(
    id: 'food-8',
    name: 'Kings Pet Mall',
    categoryId: 'food',
    position: LatLng(16.706735, 74.2407304),
    address: '',
  ),
  _PetService(
    id: 'food-9',
    name: 'Star Pet Shop & Parlor',
    categoryId: 'food',
    position: LatLng(16.6965082, 74.2434892),
    address: '',
  ),
  _PetService(
    id: 'food-10',
    name: 'Fish Planet And Pet Shop',
    categoryId: 'food',
    position: LatLng(16.689251, 74.2249559),
    address: '',
  ),
];

class _PetService {
  const _PetService({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.position,
    required this.address,
  });

  final String id;
  final String name;
  final String categoryId;
  final LatLng position;
  final String address;
}

class _RouteInstruction {
  const _RouteInstruction({
    required this.distanceFromStart,
    required this.text,
    required this.maneuver,
  });

  final double distanceFromStart;
  final String text;
  final String maneuver;
}

class PetMapScreen extends StatefulWidget {
  const PetMapScreen({super.key});

  @override
  State<PetMapScreen> createState() => _PetMapScreenState();
}

class _PetMapScreenState extends State<PetMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final AnimationController _positionAnimationController;

  StreamSubscription<Position>? _positionSubscription;
  LatLng? _currentPosition;
  LatLng? _animationStartPosition;
  LatLng? _animationTargetPosition;
  LatLng? _source;
  LatLng? _destination;
  _PetService? _selectedPlace;
  _Endpoint _selectedEndpoint = _Endpoint.destination;
  String _sourceName = 'My current location';
  String _destinationName = '';
  String _selectedCategory = 'all';
  String _locationError = '';
  final List<_PetService> _services = _mappedServices;
  List<LatLng> _routePoints = [];
  List<double> _routeSegmentLengths = [];
  List<double> _routeCumulativeDistances = [];
  List<_RouteInstruction> _routeInstructions = [];
  double _routeDistanceMeters = 0;
  double _routeGeometryDistanceMeters = 0;
  double _routeDurationSeconds = 0;
  double _remainingDistanceMeters = 0;
  double _remainingDurationSeconds = 0;
  int _routeProgressIndex = 0;
  double _routeProgressMeters = 0;
  LatLng? _routeProgressPosition;
  int _currentInstructionIndex = 0;
  double _headingDegrees = 0;
  double _animationStartHeading = 0;
  double _animationTargetHeading = 0;
  int _routeRequestId = 0;
  int _offRouteUpdates = 0;
  DateTime? _lastRerouteAt;
  bool _isLoadingLocation = true;
  bool _isLoadingRoute = false;
  bool _isNavigating = false;
  bool _isPickingOnMap = false;
  bool _isRerouting = false;

  @override
  void initState() {
    super.initState();
    _positionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(_followAnimatedPosition);
    _initializeLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _positionAnimationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  LatLng? get _displayPosition {
    final start = _animationStartPosition;
    final target = _animationTargetPosition ?? _currentPosition;
    if (start == null || target == null) return _currentPosition;
    final progress = Curves.easeOutCubic.transform(
      _positionAnimationController.value,
    );
    return LatLng(
      start.latitude + (target.latitude - start.latitude) * progress,
      start.longitude + (target.longitude - start.longitude) * progress,
    );
  }

  double get _displayHeading {
    final progress = Curves.easeOutCubic.transform(
      _positionAnimationController.value,
    );
    final difference =
        (_animationTargetHeading - _animationStartHeading + 540) % 360 - 180;
    return (_animationStartHeading + difference * progress + 360) % 360;
  }

  void _followAnimatedPosition() {
    if (!_isNavigating) return;
    final point = _displayPosition;
    if (point == null) return;

    _mapController.moveAndRotate(
      point,
      math.max(_mapController.camera.zoom, 15).toDouble(),
      -_displayHeading,
    );
  }

  Future<void> _initializeLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationException(
          'Turn on location services to find nearby pet services.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const _LocationException(
          'Location permission was denied. Allow location access to use the map.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _LocationException(
          'Location permission is disabled for PawStay. Enable it in Settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;

      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = point;
        _animationStartPosition = point;
        _animationTargetPosition = point;
        _source = point;
        _sourceName = 'My current location';
        _isLoadingLocation = false;
        _locationError = '';
        if (position.heading.isFinite && position.heading >= 0) {
          _headingDegrees = position.heading;
        }
        _animationStartHeading = _headingDegrees;
        _animationTargetHeading = _headingDegrees;
      });
      _mapController.move(point, 14);
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 1,
            ),
          ).listen(
            _onPositionUpdate,
            onError: (Object error) {
              if (mounted) {
                _showMessage('Live location updates stopped: $error');
              }
            },
          );
    } on _LocationException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _locationError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _locationError = 'Could not get your location: $error';
      });
    }
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;
    final point = LatLng(position.latitude, position.longitude);
    final startPosition = _displayPosition ?? _currentPosition ?? point;
    final startHeading = _displayHeading;
    final targetHeading = position.heading.isFinite && position.heading >= 0
        ? position.heading
        : _headingDegrees;

    setState(() {
      _currentPosition = point;
      _animationStartPosition = startPosition;
      _animationTargetPosition = point;
      _animationStartHeading = startHeading;
      _animationTargetHeading = targetHeading;
      if (position.heading.isFinite && position.heading >= 0) {
        _headingDegrees = targetHeading;
      }
      if (!_isNavigating && _sourceName == 'My current location') {
        _source = point;
      }
      if (_isNavigating && _routePoints.isNotEmpty) {
        _updateRouteProgress(point);
      }
    });
    _positionAnimationController.forward(from: 0);

    if (_isNavigating) {
      _checkOffRoute(point);
    }
  }

  void _setEndpoint(_Endpoint endpoint, LatLng position, String label) {
    setState(() {
      if (endpoint == _Endpoint.source) {
        _source = position;
        _sourceName = label;
      } else {
        _destination = position;
        _destinationName = label;
      }
      _selectedEndpoint = _Endpoint.destination;
      _isPickingOnMap = false;
      _selectedPlace = null;
      _routePoints = [];
      _routeSegmentLengths = [];
      _routeCumulativeDistances = [];
      _routeGeometryDistanceMeters = 0;
      _routeDistanceMeters = 0;
      _routeDurationSeconds = 0;
      _remainingDistanceMeters = 0;
      _remainingDurationSeconds = 0;
      _routeProgressIndex = 0;
      _routeProgressMeters = 0;
      _routeProgressPosition = null;
      _routeRequestId++;
      _isLoadingRoute = false;
    });
    _mapController.move(position, 15);
    if (_source != null && _destination != null) {
      unawaited(_requestRoute().then((_) {}));
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (!_isPickingOnMap) {
      setState(() => _selectedPlace = null);
      return;
    }
    final endpoint = _selectedEndpoint;
    _setEndpoint(
      endpoint,
      point,
      endpoint == _Endpoint.source ? 'Map location (source)' : 'Map location',
    );
  }

  Future<bool> _requestRoute({LatLng? origin}) async {
    final start = origin ?? _source;
    final end = _destination;
    if (start == null || end == null) {
      _showMessage('Choose both a source and destination first.');
      return false;
    }
    final requestId = ++_routeRequestId;
    setState(() => _isLoadingRoute = true);
    try {
      final uri = Uri.https(
        'router.project-osrm.org',
        '/route/v1/driving/'
            '${start.longitude},${start.latitude};'
            '${end.longitude},${end.latitude}',
        {'overview': 'full', 'geometries': 'geojson', 'steps': 'true'},
      );
      final response = await http
          .get(uri, headers: const {'User-Agent': _osmUserAgent})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw HttpException('Route service returned ${response.statusCode}.');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') {
        throw HttpException('No driving route was found between these places.');
      }
      final route =
          (body['routes'] as List<dynamic>).first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;
      final points = coordinates.map((coordinate) {
        final values = coordinate as List<dynamic>;
        return LatLng(
          (values[1] as num).toDouble(),
          (values[0] as num).toDouble(),
        );
      }).toList();
      if (points.length < 2) {
        throw const HttpException(
          'The route service returned no route geometry.',
        );
      }
      final segmentLengths = <double>[
        for (var i = 0; i < points.length - 1; i++)
          Geolocator.distanceBetween(
            points[i].latitude,
            points[i].longitude,
            points[i + 1].latitude,
            points[i + 1].longitude,
          ),
      ];
      final cumulativeDistances = <double>[0];
      for (final segmentLength in segmentLengths) {
        cumulativeDistances.add(cumulativeDistances.last + segmentLength);
      }
      final instructions = _parseRouteInstructions(
        route,
        points,
        cumulativeDistances,
      );
      if (!mounted || requestId != _routeRequestId) return false;
      setState(() {
        _routePoints = points;
        _routeSegmentLengths = segmentLengths;
        _routeCumulativeDistances = cumulativeDistances;
        _routeInstructions = instructions;
        _routeGeometryDistanceMeters = _routeCumulativeDistances.last;
        _routeDistanceMeters = (route['distance'] as num).toDouble();
        _routeDurationSeconds = (route['duration'] as num).toDouble();
        _routeProgressIndex = 0;
        _routeProgressMeters = 0;
        _routeProgressPosition = points.first;
        _currentInstructionIndex = 0;
        _remainingDistanceMeters = _routeDistanceMeters;
        _remainingDurationSeconds = _routeDurationSeconds;
        if (_isNavigating) _updateRouteProgress(_currentPosition ?? start);
        _isLoadingRoute = false;
      });
      if (!_isNavigating) {
        _fitRoute(points);
      } else if (_currentPosition case final position?) {
        _mapController.move(position, 17);
      }
      return true;
    } catch (error) {
      if (!mounted || requestId != _routeRequestId) return false;
      setState(() => _isLoadingRoute = false);
      _showMessage('Could not calculate route: $error');
      return false;
    }
  }

  List<_RouteInstruction> _parseRouteInstructions(
    Map<String, dynamic> route,
    List<LatLng> routePoints,
    List<double> cumulativeDistances,
  ) {
    final rawLegs = route['legs'];
    if (rawLegs is! List) return const [];

    final instructions = <_RouteInstruction>[];
    for (final rawLeg in rawLegs) {
      if (rawLeg is! Map<String, dynamic>) continue;
      final rawSteps = rawLeg['steps'];
      if (rawSteps is! List) continue;
      for (final rawStep in rawSteps) {
        if (rawStep is! Map<String, dynamic>) continue;
        final maneuver = rawStep['maneuver'];
        if (maneuver is! Map<String, dynamic>) continue;

        final location = maneuver['location'];
        if (location is! List || location.length < 2) continue;
        final longitude = location[0];
        final latitude = location[1];
        if (longitude is! num || latitude is! num) continue;
        final maneuverPoint = LatLng(latitude.toDouble(), longitude.toDouble());

        var nearestIndex = 0;
        var nearestDistance = double.infinity;
        for (var i = 0; i < routePoints.length; i++) {
          final point = routePoints[i];
          final distance = Geolocator.distanceBetween(
            maneuverPoint.latitude,
            maneuverPoint.longitude,
            point.latitude,
            point.longitude,
          );
          if (distance < nearestDistance) {
            nearestDistance = distance;
            nearestIndex = i;
          }
        }

        final type = maneuver['type']?.toString() ?? '';
        final modifier = maneuver['modifier']?.toString() ?? '';
        final name = rawStep['name']?.toString().trim() ?? '';
        final instruction = _instructionText(
          type: type,
          modifier: modifier,
          roadName: name,
        );
        if (instruction.isEmpty) continue;
        final distanceFromStart = cumulativeDistances[nearestIndex];
        if (instructions.isNotEmpty &&
            distanceFromStart < instructions.last.distanceFromStart) {
          continue;
        }
        instructions.add(
          _RouteInstruction(
            distanceFromStart: distanceFromStart,
            text: instruction,
            maneuver: modifier,
          ),
        );
      }
    }
    return instructions;
  }

  String _instructionText({
    required String type,
    required String modifier,
    required String roadName,
  }) {
    final road = roadName.isEmpty ? '' : ' onto $roadName';
    switch (type) {
      case 'depart':
        return roadName.isEmpty
            ? 'Head toward your destination'
            : 'Head toward $roadName';
      case 'arrive':
        return 'Arrive at your destination';
      case 'roundabout':
      case 'rotary':
        return 'Enter the roundabout$road';
      case 'exit roundabout':
      case 'exit rotary':
        return 'Exit the roundabout$road';
      case 'merge':
        return 'Merge$road';
      case 'fork':
        return 'Keep ${modifier.isEmpty ? 'ahead' : modifier}$road';
      case 'end of road':
        return 'At the end of the road, turn ${modifier.isEmpty ? 'ahead' : modifier}$road';
      case 'use lane':
        return 'Use the ${modifier.isEmpty ? 'appropriate' : modifier} lane$road';
      case 'turn':
      case 'continue':
      case 'new name':
      case 'on ramp':
      case 'off ramp':
      case 'notification':
        if (modifier.isEmpty || modifier == 'straight') {
          return roadName.isEmpty
              ? 'Continue straight'
              : 'Continue on $roadName';
        }
        final action = switch (modifier) {
          'uturn' || 'u-turn' => 'Make a U-turn',
          'sharp left' => 'Turn sharp left',
          'sharp right' => 'Turn sharp right',
          'slight left' => 'Turn slight left',
          'slight right' => 'Turn slight right',
          'left' => 'Turn left',
          'right' => 'Turn right',
          _ => 'Continue',
        };
        return '$action$road';
      default:
        return roadName.isEmpty ? '' : 'Continue on $roadName';
    }
  }

  void _fitRoute(List<LatLng> points) {
    if (points.length < 2) return;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(44, 250, 44, 260),
      ),
    );
  }

  Future<void> _startNavigation() async {
    if (_destination == null) {
      _showMessage('Choose a destination before starting navigation.');
      return;
    }
    if (_currentPosition == null) {
      await _initializeLocation();
      if (_currentPosition == null) return;
    }

    setState(() {
      _isNavigating = true;
      _source = _currentPosition;
      _sourceName = 'My current location';
      _routePoints = [];
      _routeSegmentLengths = [];
      _routeCumulativeDistances = [];
      _routeInstructions = [];
      _routeGeometryDistanceMeters = 0;
      _routeDistanceMeters = 0;
      _routeDurationSeconds = 0;
      _remainingDistanceMeters = 0;
      _remainingDurationSeconds = 0;
      _routeProgressIndex = 0;
      _routeProgressMeters = 0;
      _routeProgressPosition = null;
      _currentInstructionIndex = 0;
    });
    final routeReady = await _requestRoute(origin: _currentPosition);
    if (!mounted || !routeReady) {
      if (mounted) setState(() => _isNavigating = false);
      return;
    }
    if (_currentPosition != null) {
      setState(() => _updateRouteProgress(_currentPosition!));
    }
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _offRouteUpdates = 0;
    });
  }

  void _updateRouteProgress(LatLng position) {
    if (_routePoints.length < 2 || _routeSegmentLengths.isEmpty) return;
    var nearestIndex = _routeProgressIndex.clamp(
      0,
      _routeSegmentLengths.length - 1,
    );
    var nearestDistance = double.infinity;
    var nearestFraction = 0.0;
    LatLng? nearestPoint;
    const earthRadiusMeters = 6371000.0;
    final referenceLatitude = position.latitude * math.pi / 180;

    for (var i = nearestIndex; i < _routeSegmentLengths.length; i++) {
      final a = _routePoints[i];
      final b = _routePoints[i + 1];
      final ax =
          (a.longitude - position.longitude) *
          math.pi /
          180 *
          earthRadiusMeters *
          math.cos(referenceLatitude);
      final ay =
          (a.latitude - position.latitude) * math.pi / 180 * earthRadiusMeters;
      final bx =
          (b.longitude - position.longitude) *
          math.pi /
          180 *
          earthRadiusMeters *
          math.cos(referenceLatitude);
      final by =
          (b.latitude - position.latitude) * math.pi / 180 * earthRadiusMeters;
      final dx = bx - ax;
      final dy = by - ay;
      final lengthSquared = dx * dx + dy * dy;
      final fraction = lengthSquared == 0
          ? 0.0
          : (-(ax * dx + ay * dy) / lengthSquared).clamp(0.0, 1.0).toDouble();
      final projectedPoint = LatLng(
        a.latitude + (b.latitude - a.latitude) * fraction,
        a.longitude + (b.longitude - a.longitude) * fraction,
      );
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        projectedPoint.latitude,
        projectedPoint.longitude,
      );
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
        nearestFraction = fraction;
        nearestPoint = projectedPoint;
      }
    }

    if (nearestPoint == null) return;
    final projectedProgress =
        _routeCumulativeDistances[nearestIndex] +
        _routeSegmentLengths[nearestIndex] * nearestFraction;
    if (projectedProgress >= _routeProgressMeters) {
      _routeProgressIndex = nearestIndex;
      _routeProgressMeters = projectedProgress;
      _routeProgressPosition = nearestPoint;
    }
    while (_currentInstructionIndex < _routeInstructions.length - 1 &&
        _routeInstructions[_currentInstructionIndex].distanceFromStart <=
            _routeProgressMeters + 25) {
      _currentInstructionIndex++;
    }
    final geometryRemaining =
        (_routeGeometryDistanceMeters - _routeProgressMeters).clamp(
          0.0,
          _routeGeometryDistanceMeters,
        );
    final ratio = _routeGeometryDistanceMeters == 0
        ? 0.0
        : geometryRemaining / _routeGeometryDistanceMeters;
    _remainingDistanceMeters = _routeDistanceMeters * ratio;
    _remainingDurationSeconds = _routeDurationSeconds * ratio;
  }

  void _checkOffRoute(LatLng position) {
    if (!_isNavigating || _routePoints.isEmpty || _isRerouting) return;
    final startIndex = math.max(0, _routeProgressIndex - 2).toInt();
    var nearestDistance = double.infinity;
    for (var i = startIndex; i < _routePoints.length; i++) {
      final point = _routePoints[i];
      nearestDistance = math.min(
        nearestDistance,
        Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          point.latitude,
          point.longitude,
        ),
      );
    }

    if (nearestDistance > 65) {
      _offRouteUpdates++;
      final lastReroute = _lastRerouteAt;
      final canReroute =
          lastReroute == null ||
          DateTime.now().difference(lastReroute) > const Duration(seconds: 12);
      if (_offRouteUpdates >= 2 && canReroute) {
        _offRouteUpdates = 0;
        _lastRerouteAt = DateTime.now();
        unawaited(_recalculateFromCurrentPosition());
      }
    } else {
      _offRouteUpdates = 0;
    }
  }

  Future<void> _recalculateFromCurrentPosition() async {
    if (_currentPosition == null || _destination == null || _isRerouting) {
      return;
    }
    setState(() => _isRerouting = true);
    _showMessage('You are off route. Finding a new route…');
    await _requestRoute(origin: _currentPosition);
    if (mounted) setState(() => _isRerouting = false);
  }

  List<_PetService> get _visibleServices => _services
      .where(
        (service) =>
            _selectedCategory == 'all' ||
            service.categoryId == _selectedCategory,
      )
      .toList();

  _PetService? get _nearestService {
    final position = _currentPosition;
    if (position == null || _visibleServices.isEmpty) return null;
    return _visibleServices.reduce(
      (nearest, service) =>
          _distanceToService(service, position) <
              _distanceToService(nearest, position)
          ? service
          : nearest,
    );
  }

  double _distanceToService(_PetService service, LatLng position) =>
      Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        service.position.latitude,
        service.position.longitude,
      );

  _RouteInstruction? get _currentInstruction =>
      _routeInstructions.isEmpty ||
          _currentInstructionIndex >= _routeInstructions.length
      ? null
      : _routeInstructions[_currentInstructionIndex];

  void _selectCategory(String categoryId) {
    setState(() {
      _selectedCategory = categoryId;
      _selectedPlace = null;
    });
  }

  List<Marker> get _markers {
    final markers = <Marker>[
      for (final service in _visibleServices)
        Marker(
          point: service.position,
          width: 44,
          height: 52,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => setState(() => _selectedPlace = service),
            child: _serviceMarker(_categoryById(service.categoryId)),
          ),
        ),
      if (_source != null && _sourceName != 'My current location')
        Marker(
          point: _source!,
          width: 38,
          height: 42,
          child: const Icon(
            Icons.trip_origin_rounded,
            color: Color(0xFF438B57),
            size: 32,
          ),
        ),
      if (_displayPosition case final point?)
        Marker(
          point: point,
          width: 42,
          height: 42,
          child: Transform.rotate(
            angle: _displayHeading * math.pi / 180,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2367C9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8),
                ],
              ),
              child: const Icon(
                Icons.navigation_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      if (_destination case final point?)
        Marker(
          point: point,
          width: 38,
          height: 46,
          alignment: Alignment.topCenter,
          child: const Icon(
            Icons.location_on_rounded,
            color: Color(0xFF242C38),
            size: 42,
          ),
        ),
    ];
    return markers;
  }

  List<Polyline> get _polylines {
    if (_routePoints.length < 2) return const [];
    final progressPosition = _routeProgressPosition;
    final points = _isNavigating && progressPosition != null
        ? [progressPosition, ..._routePoints.skip(_routeProgressIndex + 1)]
        : _routePoints;
    if (points.length < 2) return const [];
    return [
      Polyline(
        points: points,
        color: PawStayTheme.primary,
        strokeWidth: 6,
        borderColor: Colors.white,
        borderStrokeWidth: 2,
      ),
    ];
  }

  Widget _serviceMarker(_ServiceCategory category) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: category.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(category.icon, color: Colors.white, size: 19),
        ),
        CustomPaint(
          size: const Size(10, 7),
          painter: _MarkerTailPainter(category.color),
        ),
      ],
    );
  }

  Widget _buildTopPanel() {
    if (_isNavigating) return _buildNavigationGuidance();

    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Material(
          color: colors.surface,
          elevation: 5,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedCategory == 'all'
                            ? 'Mapped pet services'
                            : 'Mapped ${_categoryById(_selectedCategory).label.toLowerCase()}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Showing ${_services.length} saved places at their supplied coordinates',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                _endpointField(
                  endpoint: _Endpoint.source,
                  icon: Icons.trip_origin_rounded,
                  label: _sourceName,
                  hint: 'Tap to choose the starting point',
                ),
                const SizedBox(height: 7),
                _endpointField(
                  endpoint: _Endpoint.destination,
                  icon: Icons.location_on_rounded,
                  label: _destinationName,
                  hint: 'Tap to choose a destination',
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _isPickingOnMap
                            ? 'Tap the map to choose the ${_selectedEndpoint.name}.'
                            : 'Tap a location above, then choose a point on the map.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_source != null && _destination != null)
                      TextButton.icon(
                        onPressed: _isLoadingRoute
                            ? null
                            : () => _requestRoute(),
                        icon: _isLoadingRoute
                            ? const SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.route_rounded, size: 17),
                        label: const Text('Route'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
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

  Widget _buildNavigationGuidance() {
    const guidanceColor = Color(0xFFD77D5A);
    const nextInstructionColor = Color(0xFFBD6449);
    final instruction = _currentInstruction;
    final remainingToManeuver = instruction == null
        ? 0.0
        : (instruction.distanceFromStart - _routeProgressMeters)
              .clamp(0.0, double.infinity)
              .toDouble();
    final nextInstructionIndex = _currentInstructionIndex + 1;
    final nextInstruction = nextInstructionIndex < _routeInstructions.length
        ? _routeInstructions[nextInstructionIndex]
        : null;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Material(
          color: guidanceColor,
          elevation: 8,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _maneuverIcon(instruction?.maneuver ?? 'straight'),
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'towards',
                            style: const TextStyle(
                              color: Color(0xFFFFE6DC),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            instruction?.text ??
                                'Continue to ${_destinationName.isEmpty ? 'your destination' : _destinationName}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            instruction == null
                                ? 'Follow the highlighted route'
                                : remainingToManeuver < 25
                                ? 'Turn now'
                                : 'In ${_formatDistance(remainingToManeuver)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFFFE6DC),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (nextInstruction != null)
                Container(
                  color: nextInstructionColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Then',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _maneuverIcon(nextInstruction.maneuver),
                        color: Colors.white,
                        size: 21,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          nextInstruction.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _maneuverIcon(String modifier) => switch (modifier) {
    'left' || 'slight left' || 'sharp left' => Icons.turn_left_rounded,
    'right' || 'slight right' || 'sharp right' => Icons.turn_right_rounded,
    'uturn' || 'u-turn' => Icons.u_turn_left_rounded,
    'merge' => Icons.merge_rounded,
    _ => Icons.straight_rounded,
  };

  Widget _endpointField({
    required _Endpoint endpoint,
    required IconData icon,
    required String label,
    required String hint,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isSelected = _selectedEndpoint == endpoint;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => _beginMapPicking(endpoint),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isSelected ? PawStayTheme.primary : colors.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: endpoint == _Endpoint.source
                    ? colors.onSurfaceVariant
                    : PawStayTheme.primary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label.isEmpty ? hint : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: label.isEmpty
                        ? colors.onSurfaceVariant
                        : colors.onSurface,
                  ),
                ),
              ),
              if (endpoint == _Endpoint.source)
                IconButton(
                  tooltip: 'Use my current location',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: _currentPosition == null
                      ? null
                      : () => _setEndpoint(
                          _Endpoint.source,
                          _currentPosition!,
                          'My current location',
                        ),
                  icon: const Icon(Icons.my_location_rounded, size: 19),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _beginMapPicking(_Endpoint endpoint) {
    setState(() {
      _selectedEndpoint = endpoint;
      _isPickingOnMap = true;
    });
  }

  Widget _buildCategoryFilters() {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = category.id == _selectedCategory;
          return FilterChip(
            selected: selected,
            showCheckmark: false,
            avatar: Icon(category.icon, size: 17, color: category.color),
            label: Text(category.label),
            selectedColor: category.color.withValues(alpha: 0.14),
            backgroundColor: colors.surface,
            side: BorderSide(
              color: selected ? category.color : colors.outlineVariant,
            ),
            labelStyle: TextStyle(
              color: selected ? category.color : colors.onSurface,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
            onSelected: (_) => _selectCategory(category.id),
          );
        },
      ),
    );
  }

  Widget _buildBottomCard() {
    final colors = Theme.of(context).colorScheme;
    final place = _selectedPlace;
    final hasRoute = _routePoints.length > 1;
    final distance = _isNavigating
        ? _remainingDistanceMeters
        : _routeDistanceMeters;
    final duration = _isNavigating
        ? _remainingDurationSeconds
        : _routeDurationSeconds;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Material(
          color: Colors.white,
          elevation: 7,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Padding(
            padding: EdgeInsets.fromLTRB(15, _isNavigating ? 7 : 15, 15, 15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isNavigating) ...[
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4DAE2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
                _isNavigating
                    ? _buildNavigationBottom(colors, distance, duration)
                    : place != null
                    ? _buildPlaceDetails(place, colors)
                    : hasRoute
                    ? _buildRouteDetails(colors, distance, duration)
                    : _buildNearbySummary(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationBottom(
    ColorScheme colors,
    double distance,
    double duration,
  ) {
    final arrival = DateTime.now().add(Duration(seconds: duration.round()));
    final arrivalText =
        '${arrival.hour.toString().padLeft(2, '0')}:'
        '${arrival.minute.toString().padLeft(2, '0')}';

    return Row(
      children: [
        IconButton(
          tooltip: 'End navigation',
          onPressed: _stopNavigation,
          style: IconButton.styleFrom(
            foregroundColor: const Color(0xFF384354),
            side: const BorderSide(color: Color(0xFFE0E5EC)),
            shape: const CircleBorder(),
            fixedSize: const Size(54, 54),
          ),
          icon: const Icon(Icons.close_rounded, size: 30),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatDuration(duration),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFFE47B32),
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text(
                    _formatDistance(distance),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF566174),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text('·', style: TextStyle(color: Color(0xFF8993A2))),
                  Text(
                    arrivalText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF566174),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text('·', style: TextStyle(color: Color(0xFF8993A2))),
                  const Icon(Icons.circle, size: 7, color: Color(0xFF36A873)),
                  Text(
                    'On route',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF36A873),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Recenter on my location',
          onPressed: _currentPosition == null
              ? null
              : () {
                  _mapController.move(_currentPosition!, 17);
                  _mapController.rotate(-_headingDegrees);
                },
          style: IconButton.styleFrom(
            foregroundColor: const Color(0xFF438BFF),
            backgroundColor: const Color(0xFFE8F1FF),
            shape: const CircleBorder(),
            fixedSize: const Size(54, 54),
          ),
          icon: const Icon(Icons.navigation_rounded),
        ),
      ],
    );
  }

  Widget _buildNearbySummary(ColorScheme colors) {
    final count = _visibleServices.length;
    final position = _currentPosition;
    final nearest = _nearestService;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: PawStayTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.pets_rounded, color: PawStayTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isLoadingLocation
                    ? 'Finding your location…'
                    : _locationError.isNotEmpty
                    ? 'Location unavailable'
                    : _selectedCategory == 'all'
                    ? '$count mapped pet services'
                    : '$count mapped ${_categoryById(_selectedCategory).label.toLowerCase()}',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                _locationError.isNotEmpty
                    ? _locationError
                    : position == null
                    ? 'Allow location access to find the nearest mapped service.'
                    : nearest == null
                    ? 'No mapped services in this category.'
                    : 'Nearest: ${nearest.name} · '
                          '${_formatDistance(_distanceToService(nearest, position))} away.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Center on my location',
          onPressed: _currentPosition == null
              ? _initializeLocation
              : () => _mapController.move(_currentPosition!, 15),
          icon: const Icon(Icons.my_location_rounded),
        ),
      ],
    );
  }

  Widget _buildRouteDetails(
    ColorScheme colors,
    double distance,
    double duration,
  ) {
    final arrival = DateTime.now().add(Duration(seconds: duration.round()));
    final arrivalText =
        '${arrival.hour.toString().padLeft(2, '0')}:'
        '${arrival.minute.toString().padLeft(2, '0')}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _isNavigating ? 'Live navigation' : 'Route overview',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (_isNavigating)
              TextButton(onPressed: _stopNavigation, child: const Text('End'))
            else
              FilledButton.icon(
                onPressed: _isLoadingRoute ? null : _startNavigation,
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('Start'),
              ),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            _routeMetric(
              icon: Icons.route_rounded,
              value: _formatDistance(distance),
              label: 'remaining',
              colors: colors,
            ),
            const SizedBox(width: 18),
            _routeMetric(
              icon: Icons.schedule_rounded,
              value: _formatDuration(duration),
              label: 'estimated',
              colors: colors,
            ),
            const SizedBox(width: 18),
            _routeMetric(
              icon: Icons.flag_rounded,
              value: arrivalText,
              label: 'arrival',
              colors: colors,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Driving route via OSRM · ETA adjusts with your live position',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _routeMetric({
    required IconData icon,
    required String value,
    required String label,
    required ColorScheme colors,
  }) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 17, color: PawStayTheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceDetails(_PetService place, ColorScheme colors) {
    final category = _categoryById(place.categoryId);
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(category.icon, color: category.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                place.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                '${category.label} · '
                '${place.position.latitude.toStringAsFixed(6)}, '
                '${place.position.longitude.toStringAsFixed(6)}'
                '${place.address.isEmpty ? '' : ' · ${place.address}'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Route to this place',
          onPressed: () {
            _setEndpoint(_Endpoint.destination, place.position, place.name);
            setState(() => _selectedPlace = null);
          },
          icon: const Icon(Icons.directions_rounded),
        ),
      ],
    );
  }

  Widget _buildMapControls() {
    if (_isNavigating) {
      return Positioned(
        right: 14,
        bottom: 128,
        child: FloatingActionButton.small(
          heroTag: 'navigation_recenter',
          tooltip: 'Recenter on my location',
          onPressed: _currentPosition == null
              ? null
              : () {
                  _mapController.move(_currentPosition!, 17);
                  _mapController.rotate(-_headingDegrees);
                },
          child: const Icon(Icons.my_location_rounded),
        ),
      );
    }

    return Positioned(
      right: 14,
      bottom: 170,
      child: Column(
        children: [
          FloatingActionButton.small(
            heroTag: 'map_zoom_in',
            tooltip: 'Zoom in',
            onPressed: () => _mapController.move(
              _mapController.camera.center,
              _mapController.camera.zoom + 1,
            ),
            child: const Icon(Icons.add_rounded),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'map_location',
            tooltip: 'Center on my location',
            onPressed: _currentPosition == null
                ? _initializeLocation
                : () => _mapController.move(
                    _currentPosition!,
                    math.max(_mapController.camera.zoom, 15).toDouble(),
                  ),
            child: const Icon(Icons.my_location_rounded),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'map_pick',
            tooltip: 'Pick a point on the map',
            backgroundColor: _isPickingOnMap
                ? PawStayTheme.primary
                : Theme.of(context).colorScheme.surface,
            foregroundColor: _isPickingOnMap
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
            onPressed: () => setState(() {
              _isPickingOnMap = !_isPickingOnMap;
              if (_isPickingOnMap) {
                _selectedPlace = null;
              }
            }),
            child: const Icon(Icons.add_location_alt_rounded),
          ),
        ],
      ),
    );
  }

  static String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String _formatDuration(double seconds) {
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes == 0
        ? '${hours}h'
        : '${hours}h ${remainingMinutes}m';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: _isNavigating
          ? null
          : AppBar(title: const Text('Pet services map')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? _initialMapCenter,
              initialZoom: _currentPosition == null ? 12 : 14,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_application_1',
                maxZoom: 19,
              ),
              if (_polylines.isNotEmpty) PolylineLayer(polylines: _polylines),
              AnimatedBuilder(
                animation: _positionAnimationController,
                builder: (context, child) => MarkerLayer(markers: _markers),
              ),
            ],
          ),
          Column(
            children: [
              _buildTopPanel(),
              if (!_isNavigating) ...[
                const SizedBox(height: 8),
                _buildCategoryFilters(),
              ],
              const Spacer(),
              _buildBottomCard(),
            ],
          ),
          _buildMapControls(),
          Positioned(
            right: 14,
            bottom: 145,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                child: Text(
                  '© PawStay Map 2026 ',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationException implements Exception {
  const _LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HttpException implements Exception {
  const HttpException(this.message);

  final String message;

  @override
  String toString() => message;
}

_ServiceCategory _categoryById(String id) =>
    _categories.firstWhere((category) => category.id == id);

class _MarkerTailPainter extends CustomPainter {
  const _MarkerTailPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MarkerTailPainter oldDelegate) =>
      oldDelegate.color != color;
}
