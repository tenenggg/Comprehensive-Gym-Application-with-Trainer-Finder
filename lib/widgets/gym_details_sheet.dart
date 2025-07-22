import 'package:flutter/material.dart';
import '../models/gym_location.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

class GymDetailsSheet extends StatelessWidget {
  final GymLocation gym;
  final VoidCallback onClose;
  final VoidCallback? onNavigate;

  const GymDetailsSheet({
    Key? key,
    required this.gym,
    required this.onClose,
    this.onNavigate,
  }) : super(key: key);

  Future<void> _navigateToGym() async {
    try {
      final url = Platform.isIOS 
          ? 'maps://?q=${gym.latitude},${gym.longitude}'
          : 'https://www.google.com/maps/dir/?api=1&destination=${gym.latitude},${gym.longitude}&travelmode=driving';
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch navigation';
      }
    } catch (e) {
      print('Error launching navigation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Gym Image Banner
          Container(
            height: 200,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              image: DecorationImage(
                image: (gym.photos.isNotEmpty
                        ? NetworkImage(gym.photos.first)
                        : const AssetImage('assets/images/default_gym.png'))
                    as ImageProvider,
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.3),
                  BlendMode.darken,
                ),
              ),
            ),
            child: gym.photos.isEmpty
                ? const Center(
                    child: Icon(
                      Icons.business,
                      size: 50,
                      color: Colors.white54,
                    ),
                  )
                : null,
          ),
          
          // Close button
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gym name and rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          gym.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            gym.rating.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Distance
                  Text(
                    '${gym.distanceInKm.toStringAsFixed(1)} km away',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Address
                  _buildInfoRow(
                    context,
                    Icons.location_on,
                    gym.address,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Phone number
                  if (gym.phoneNumber.isNotEmpty)
                    _buildInfoRow(
                      context,
                      Icons.phone,
                      gym.phoneNumber,
                      onTap: () => _launchUrl('tel:${gym.phoneNumber}'),
                    ),
                  
                  const SizedBox(height: 8),
                  
                  // Website
                  if (gym.website.isNotEmpty)
                    _buildInfoRow(
                      context,
                      Icons.language,
                      gym.website,
                      onTap: () => _launchUrl(gym.website),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Open/Closed status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: gym.isOpen ? Colors.green[100] : Colors.red[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      gym.isOpen ? 'Open' : 'Closed',
                      style: TextStyle(
                        color: gym.isOpen ? Colors.green[800] : Colors.red[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Photos
                  if (gym.photos.isNotEmpty) ...[
                    Text(
                      'Photos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: gym.photos.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                gym.photos[index],
                                width: 160,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 160,
                                    height: 120,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.error),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Amenities
                  if (gym.amenities.isNotEmpty) ...[
                    Text(
                      'Amenities',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: gym.amenities.map((amenity) {
                        return Chip(
                          label: Text(amenity),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        );
                      }).toList(),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Navigation button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.directions),
                      label: const Text('Navigate to Gym'),
                      onPressed: onNavigate ?? _navigateToGym,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String text, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: onTap != null
                    ? Theme.of(context).colorScheme.primary
                    : null,
                decoration: onTap != null ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
} 