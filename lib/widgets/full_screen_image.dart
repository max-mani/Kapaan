import 'dart:convert';
import 'package:flutter/material.dart';

class FullScreenImage extends StatelessWidget {
  final String? base64Image;
  final String? imagePath;
  final bool isAsset;

  const FullScreenImage({
    super.key,
    this.base64Image,
    this.imagePath,
    this.isAsset = false,
  }) : assert(base64Image != null || imagePath != null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: base64Image != null
              ? Image.memory(
                  base64Decode(base64Image!),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.error,
                    color: Colors.red,
                    size: 50,
                  ),
                )
              : isAsset
                  ? Image.asset(
                      imagePath!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 50,
                      ),
                    )
                  : Image.network(
                      imagePath!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
        ),
      ),
    );
  }
} 