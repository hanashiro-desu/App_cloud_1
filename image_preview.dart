import 'package:flutter/material.dart';

class ImagePreview extends StatelessWidget {
  final String imageUrl;

  const ImagePreview({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Center(child: Image.network(imageUrl));
  }
}
