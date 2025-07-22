import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'dart:async';
import '../../config/mapbox_config.dart';
import '../../models/gym_location.dart';
import '../../services/gym_service.dart';
import '../../widgets/gym_marker.dart';
import '../../widgets/gym_details_sheet.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

class MyAnnotationClickListener implements OnPointAnnotationClickListener {
  final List<GymLocation> nearbyGyms;
  final Function(GymLocation) onGymSelected;

  MyAnnotationClickListener({
    required this.nearbyGyms,
    required this.onGymSelected,
  });

  @override
  bool onPointAnnotationClick(PointAnnotation annotation) {
    print('Annotation clicked: \\${annotation.id}');
    final coordinates = annotation.geometry.coordinates;
    final matchingGym = nearbyGyms.firstWhere(
      (gym) =>
        (gym.latitude - coordinates.lat).abs() < 0.0001 &&
        (gym.longitude - coordinates.lng).abs() < 0.0001,
      orElse: () => nearbyGyms.first,
    );
    onGymSelected(matchingGym);
    return true;
  }
}

class GymFinderPage extends StatefulWidget {
  const GymFinderPage({Key? key}) : super(key: key);

  @override
  State<GymFinderPage> createState() => _GymFinderPageState();
}

class _GymFinderPageState extends State<GymFinderPage> {
  MapboxMap? mapboxMap;
  PointAnnotationManager? annotationManager;
  geo.Position? currentPosition;
  bool isLoading = true;
  List<GymLocation> nearbyGyms = [];
  GymLocation? selectedGym;
  final TextEditingController _searchController = TextEditingController();
  bool isSearching = false;
  Timer? _idleTimer;
  bool _showMap = true;

  // --- FAKE LOCATION STATE ---
  bool _useFakeLocation = false;
  final TextEditingController _fakeLatController = TextEditingController();
  final TextEditingController _fakeLngController = TextEditingController();
  double? _fakeLat;
  double? _fakeLng;
  // --- END FAKE LOCATION STATE ---

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _idleTimer?.cancel();
    _fakeLatController.dispose();
    _fakeLngController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (_useFakeLocation && _fakeLat != null && _fakeLng != null) {
      // Use fake location
      final fakePosition = geo.Position(
        latitude: _fakeLat!,
        longitude: _fakeLng!,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 0.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 1.0,
        isMocked: true,
      );
      setState(() {
        currentPosition = fakePosition;
        isLoading = false;
      });
      await _loadNearbyGyms(fakePosition);
      return;
    }
    try {
      setState(() {
        isLoading = true;
      });
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled. Please enable them.')),
        );
        return;
      }
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          return;
        }
      }
      if (permission == geo.LocationPermission.deniedForever) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied. Please enable them in settings.'),
          ),
        );
        return;
      }
      geo.Position userLocation = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      setState(() {
        currentPosition = userLocation;
        isLoading = false;
      });
      await _loadNearbyGyms(userLocation);
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  Future<void> _loadNearbyGyms(geo.Position position) async {
    try {
      setState(() {
        isLoading = true;
      });
      final mapboxGyms = await GymService.getNearbyGyms(position);
      final foursquareGyms = await GymService.getNearbyGymsFromFoursquare(position);
      final allGyms = [...mapboxGyms];
      for (final foursquareGym in foursquareGyms) {
        bool isDuplicate = false;
        for (final existingGym in allGyms) {
          final distance = geo.Geolocator.distanceBetween(
            existingGym.latitude,
            existingGym.longitude,
            foursquareGym.latitude,
            foursquareGym.longitude,
          );
          if (distance < 100) {
            isDuplicate = true;
            break;
          }
        }
        if (!isDuplicate) {
          allGyms.add(foursquareGym);
        }
      }
      allGyms.sort((a, b) => a.distance.compareTo(b.distance));
      final gymsWithDistance = allGyms.map((gym) {
        final distance = geo.Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          gym.latitude,
          gym.longitude,
        );
        return GymLocation(
          id: gym.id,
          name: gym.name,
          address: gym.address,
          latitude: gym.latitude,
          longitude: gym.longitude,
          distance: distance,
          rating: gym.rating,
          isOpen: gym.isOpen,
          phoneNumber: gym.phoneNumber,
          website: gym.website,
          photos: gym.photos,
          amenities: gym.amenities,
        );
      }).where((gym) => gym.distance <= 35000).toList();
      setState(() {
        nearbyGyms = gymsWithDistance;
        selectedGym = gymsWithDistance.isNotEmpty ? gymsWithDistance.first : null;
        isLoading = false;
      });
      await _addGymMarkersToMap();
      if (gymsWithDistance.isNotEmpty && mapboxMap != null) {
        _fitMapToGyms(gymsWithDistance);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fitMapToGyms(List<GymLocation> gyms) async {
    if (mapboxMap == null || gyms.isEmpty) return;
    try {
      double minLat = double.infinity;
      double maxLat = -double.infinity;
      double minLng = double.infinity;
      double maxLng = -double.infinity;
      for (final gym in gyms) {
        minLat = math.min(minLat, gym.latitude);
        maxLat = math.max(maxLat, gym.latitude);
        minLng = math.min(minLng, gym.longitude);
        maxLng = math.max(maxLng, gym.longitude);
      }
      final latPadding = (maxLat - minLat) * 0.1;
      final lngPadding = (maxLng - minLng) * 0.1;
      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;
      final latZoom = math.log(360 / (maxLat - minLat)) / math.ln2;
      final lngZoom = math.log(360 / (maxLng - minLng)) / math.ln2;
      final zoom = math.min(latZoom, lngZoom) - 1;
      final cameraOptions = CameraOptions(
        center: Point(
          coordinates: Position(centerLng, centerLat),
        ),
        zoom: zoom,
        padding: MbxEdgeInsets(left: 50, top: 50, right: 50, bottom: 50),
      );
      await mapboxMap!.setCamera(cameraOptions);
    } catch (e) {}
  }

  Future<void> _searchGyms(String query) async {
    if (currentPosition == null) return;
    try {
      setState(() {
        isLoading = true;
      });
      final gyms = await GymService.searchGyms(query, currentPosition!);
      setState(() {
        nearbyGyms = gyms;
        selectedGym = gyms.isNotEmpty ? gyms.first : null;
        isLoading = false;
      });
      _addGymMarkersToMap();
      if (gyms.isNotEmpty) {
        _fitMapToGyms(gyms);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _addGymMarkersToMap() async {
    if (mapboxMap == null || annotationManager == null) return;
    try {
      await annotationManager!.deleteAll();
      // Use built-in marker icon
      if (currentPosition != null) {
        final userMarkerOptions = PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              currentPosition!.longitude,
              currentPosition!.latitude,
            ),
          ),
          iconImage: 'marker-15',
          iconSize: 2.5,
          textField: 'You are here',
          textOffset: [0.0, 2.0],
          textSize: 14.0,
        );
        await annotationManager!.create(userMarkerOptions);
      }
      for (final gym in nearbyGyms) {
        final gymMarkerOptions = PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              gym.longitude,
              gym.latitude,
            ),
          ),
          iconImage: 'marker-15',
          iconSize: 2.0,
          textField: gym.name,
          textOffset: [0.0, 2.0],
          textSize: 12.0,
        );
        await annotationManager!.create(gymMarkerOptions);
      }
      annotationManager!.addOnPointAnnotationClickListener(
        MyAnnotationClickListener(
          nearbyGyms: nearbyGyms,
          onGymSelected: _showGymDetails,
        ),
      );
    } catch (e) {
      print('Error adding markers: $e');
    }
  }

  Future<void> _addUserLocationMarker() async {
    if (annotationManager == null || currentPosition == null) return;
    try {
      final userMarkerOptions = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            currentPosition!.longitude,
            currentPosition!.latitude,
          ),
        ),
        iconImage: 'marker-15',
        iconSize: 2.5,
        textField: 'You are here',
        textOffset: [0.0, 2.0],
        textSize: 14.0,
      );
      await annotationManager!.create(userMarkerOptions);
    } catch (e) {}
  }

  void _showGymDetails(GymLocation gym) {
    setState(() {
      selectedGym = gym;
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GymDetailsSheet(
        gym: gym,
        onClose: () {
          Navigator.pop(context);
          setState(() {
            selectedGym = null;
          });
        },
        onNavigate: () => _navigateToGym(gym),
      ),
    );
  }

  void _onStyleLoaded(StyleLoadedEventData event) {
    print('Map style loaded');
  }

  Future<void> _getCurrentCameraPosition(MapboxMap map) async {
    final cameraState = await map.getCameraState();
    final center = cameraState.center;
    final zoom = cameraState.zoom;
    print("Camera Center: \\${center.coordinates.lat}, \\${center.coordinates.lng}");
    print("Zoom level: $zoom");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2468),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Gym Finder',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: isLoading ? null : _getCurrentLocation,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF212E83), const Color(0xFF1A2468)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- FAKE LOCATION UI ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Switch(
                      value: _useFakeLocation,
                      onChanged: (val) {
                        setState(() {
                          _useFakeLocation = val;
                        });
                        if (!val) {
                          _getCurrentLocation();
                        }
                      },
                      activeColor: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Use Fake Location (tap map to set)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              // --- END FAKE LOCATION UI ---
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search gyms...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      _searchGyms(value);
                    }
                  },
                ),
              ),
              
              // Toggle button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: Icon(_showMap ? Icons.list : Icons.map, color: Colors.white),
                    label: Text(
                      _showMap ? 'Show List' : 'Show Map',
                      style: const TextStyle(color: Colors.white),
                    ),
                    onPressed: () {
                      setState(() {
                        _showMap = !_showMap;
                      });
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Map or List view
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : _showMap
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _buildMap(),
                          )
                        : _buildGymList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGymList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (nearbyGyms.isEmpty) {
      return const Center(
        child: Text('No gyms found within 35km. Try a different location.'),
      );
    }

    final nearbyGymsList = <String, List<GymLocation>>{
      'Under 5km': [],
      '5-15km': [],
      '15-25km': [],
      '25-35km': [],
    };

    for (final gym in nearbyGyms) {
      if (gym.distanceInKm < 5) {
        nearbyGymsList['Under 5km']!.add(gym);
      } else if (gym.distanceInKm < 15) {
        nearbyGymsList['5-15km']!.add(gym);
      } else if (gym.distanceInKm < 25) {
        nearbyGymsList['15-25km']!.add(gym);
      } else if (gym.distanceInKm <= 35) {
        nearbyGymsList['25-35km']!.add(gym);
      }
    }

    return ListView.builder(
      itemCount: nearbyGymsList.length,
      itemBuilder: (context, index) {
        final category = nearbyGymsList.keys.elementAt(index);
        final gymsInCategory = nearbyGymsList[category]!;
        if (gymsInCategory.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                category,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            ...gymsInCategory.map((gym) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    gym.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(gym.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gym.address),
                    Row(
                      children: [
                        Icon(Icons.directions_walk, size: 16, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          '${gym.distanceInKm.toStringAsFixed(1)} km',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (gym.rating > 0) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          Text(' ${gym.rating.toStringAsFixed(1)}'),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.directions),
                      onPressed: () => _navigateToGym(gym),
                      tooltip: 'Navigate to gym',
                    ),
                    gym.isOpen
                        ? const Chip(
                            label: Text('Open'),
                            backgroundColor: Colors.green,
                            labelStyle: TextStyle(color: Colors.white),
                          )
                        : const Chip(
                            label: Text('Closed'),
                            backgroundColor: Colors.red,
                            labelStyle: TextStyle(color: Colors.white),
                          ),
                  ],
                ),
                onTap: () {
                  setState(() {
                    selectedGym = gym;
                    _showMap = true;
                  });
                  _moveToGym(gym);
                },
              ),
            )).toList(),
          ],
        );
      },
    );
  }

  Future<void> _navigateToGym(GymLocation gym) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=${gym.latitude},${gym.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch navigation')),
      );
    }
  }

  Future<void> _refreshGyms() async {
    if (currentPosition != null) {
      await _loadNearbyGyms(currentPosition!);
    }
  }

  void _onSearchChanged(String value) {
    if (value.isEmpty) {
      if (currentPosition != null) {
        _loadNearbyGyms(currentPosition!);
      }
    } else {
      _searchGyms(value);
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    
    // Create annotation manager
    mapboxMap.annotations.createPointAnnotationManager().then((manager) {
      annotationManager = manager;
      _addGymMarkersToMap();
    });
  }

  void _onMapIdle(MapIdleEventData event) {
    if (_idleTimer != null) {
      _idleTimer!.cancel();
    }
    _idleTimer = Timer(const Duration(milliseconds: 500), () {
      if (mapboxMap != null) {
        _getCurrentCameraPosition(mapboxMap!);
      }
    });
  }

  Widget _buildMap() {
    return Stack(
      children: [
        MapWidget(
          onMapCreated: _onMapCreated,
          styleUri: MapboxStyles.MAPBOX_STREETS,
          cameraOptions: CameraOptions(
            center: Point(
              coordinates: Position(
                currentPosition?.longitude ?? 101.6869,
                currentPosition?.latitude ?? 3.1390,
              ),
            ),
            zoom: 14.0,
          ),
          onMapIdleListener: _onMapIdle,
          onTapListener: (MapContentGestureContext gestureContext) async {
            if (_useFakeLocation && gestureContext.point != null) {
              setState(() {
                _fakeLat = (gestureContext.point!.coordinates[1] as num?)?.toDouble();
                _fakeLng = (gestureContext.point!.coordinates[0] as num?)?.toDouble();
              });
              await _getCurrentLocation();
            }
          },
        ),
        if (_useFakeLocation && _fakeLat != null && _fakeLng != null)
          Positioned(
            top: 0,
            left: 0,
            child: Icon(
              Icons.location_on,
              color: Colors.red,
              size: 40,
            ),
          ),
        if (selectedGym != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildGymDetailsCard(selectedGym!),
          ),
      ],
    );
  }

  Widget _buildGymDetailsCard(GymLocation gym) {
    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              gym.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(gym.address),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.directions_walk, size: 16, color: Theme.of(context).primaryColor),
                const SizedBox(width: 4),
                Text(
                  '${gym.distanceInKm.toStringAsFixed(1)} km',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (gym.rating > 0) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  Text(
                    ' ${gym.rating.toStringAsFixed(1)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.directions),
                  label: const Text('Navigate'),
                  onPressed: () => _navigateToGym(gym),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _moveToGym(GymLocation gym) async {
    if (mapboxMap == null) return;
    try {
      final cameraOptions = CameraOptions(
        center: Point(
          coordinates: Position(gym.longitude, gym.latitude),
        ),
        zoom: 15.0,
      );
      await mapboxMap!.setCamera(cameraOptions);
    } catch (e) {
      print('Error moving to gym: $e');
    }
  }
} 