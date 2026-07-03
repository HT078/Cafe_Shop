import 'package:flutter/material.dart';

import '../../theme/theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 82, this.borderRadius = 24});

  static const String assetPath = 'assets/images/hai_tin_logo.png';

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.creamColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const DecoratedBox(
            decoration: BoxDecoration(gradient: AppTheme.flameGradient),
            child: Icon(
              Icons.local_fire_department_rounded,
              color: AppTheme.charColor,
              size: 48,
            ),
          );
        },
      ),
    );
  }
}
