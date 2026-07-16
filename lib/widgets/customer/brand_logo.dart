import 'package:flutter/material.dart';

import '../../theme/theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 82, this.color});

  static const String assetPath =
      'assets/images/hai_tin_logo_transparent.png';

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        color: color,
        colorBlendMode: color == null ? null : BlendMode.srcIn,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.local_cafe_rounded,
            color: color ?? AppTheme.charColor,
            size: size * 0.72,
          );
        },
      ),
    );
  }
}
