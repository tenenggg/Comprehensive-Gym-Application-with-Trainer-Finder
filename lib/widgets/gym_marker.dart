import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/gym_location.dart';
import 'package:geolocator/geolocator.dart' as geo;

class GymMarker {
  final GymLocation gym;
  final PointAnnotationManager? annotationManager;
  final Function(GymLocation) onTap;

  GymMarker({
    required this.gym,
    required this.annotationManager,
    required this.onTap,
  });

  Future<void> addToMap() async {
    if (annotationManager == null) return;

    final annotationOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(gym.longitude, gym.latitude)),
      iconImage: 'marker-15',
      iconSize: 1.5,
      textField: gym.name,
      textOffset: [0.0, -2.5],
      textSize: 12.0,
      textColor: Colors.white.value,
      textJustify: TextJustify.CENTER,
      textLetterSpacing: 1.2,
      iconColor: Colors.blue.value,
      iconHaloColor: Colors.white.value,
      iconHaloWidth: 2.0,
    );

    await annotationManager!.create(annotationOptions);
    
    // Note: Click handling is set up in the GymFinderPage
  }

  Future<void> removeFromMap() async {
    if (annotationManager == null) return;
    await annotationManager!.deleteAll();
  }
} 