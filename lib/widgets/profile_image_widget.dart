import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/profile_image_service.dart';

class ProfileImageWidget extends StatefulWidget {
  final String? imageUrl;
  final double size;
  final bool isEditable;
  final String userType;
  final Function(String?)? onImageChanged;
  final VoidCallback? onTap;
  final String? cacheKey;

  const ProfileImageWidget({
    super.key,
    this.imageUrl,
    this.size = 100,
    this.isEditable = false,
    required this.userType,
    this.onImageChanged,
    this.onTap,
    this.cacheKey,
  });

  @override
  State<ProfileImageWidget> createState() => _ProfileImageWidgetState();
}

class _ProfileImageWidgetState extends State<ProfileImageWidget> {
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap ?? (widget.isEditable ? _showImagePicker : null),
      child: Stack(
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: _buildImageWidget(),
            ),
          ),
          if (widget.isEditable)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  _isUploading ? Icons.hourglass_empty : Icons.camera_alt,
                  color: Colors.white,
                  size: widget.size * 0.2,
                ),
              ),
            ),
          if (_isUploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageWidget() {
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.imageUrl!,
        fit: BoxFit.cover,
        cacheKey: widget.cacheKey ?? widget.imageUrl,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade300,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) => _buildDefaultAvatar(),
      );
    } else {
      return _buildDefaultAvatar();
    }
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey.shade300,
      child: Icon(
        Icons.person,
        size: widget.size * 0.5,
        color: Colors.grey.shade600,
      ),
    );
  }

  Future<void> _showImagePicker() async {
    if (_isUploading) return;

    final File? selectedImage = await ProfileImageService.showImagePickerDialog(context);
    
    if (selectedImage != null) {
      await _uploadImage(selectedImage);
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final String? imageUrl = await ProfileImageService.uploadProfileImage(
        imageFile,
        widget.userType,
      );

      if (imageUrl != null) {
        if (widget.onImageChanged != null) {
          widget.onImageChanged!(imageUrl);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload profile picture'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }
}

// Simple profile image display widget (non-editable)
class ProfileImageDisplay extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final VoidCallback? onTap;
  final String? cacheKey;

  const ProfileImageDisplay({
    super.key,
    this.imageUrl,
    this.size = 80,
    this.onTap,
    this.cacheKey,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  cacheKey: cacheKey ?? imageUrl,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade300,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => _buildDefaultAvatar(),
                )
              : _buildDefaultAvatar(),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey.shade300,
      child: Icon(
        Icons.person,
        size: size * 0.5,
        color: Colors.grey.shade600,
      ),
    );
  }
} 