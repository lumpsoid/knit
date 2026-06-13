import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Shared attachment image renderer. Takes primitives only (widgets.md §1) — the
/// decoded bytes, never a sync domain type — so it is reused by card images and
/// the collection cover alike. Shows [placeholder] while [bytes] is null
/// (loading / missing) and a broken-image glyph if the bytes fail to decode.
class AttachmentImage extends StatelessWidget {
  const AttachmentImage({
    super.key,
    required this.bytes,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
  });

  final Uint8List? bytes;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final data = bytes;
    if (data == null) {
      return placeholder ??
          SizedBox(
            width: width,
            height: height,
            child: const ColoredBox(
              color: Color(0x11000000),
              child: Center(child: Icon(Icons.image_outlined)),
            ),
          );
    }
    return Image.memory(
      data,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) => SizedBox(
        width: width,
        height: height,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}
