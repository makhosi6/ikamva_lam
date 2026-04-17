import 'package:flutter/material.dart';

import '../branding/app_assets.dart';

/// Raster brand mark; vector source: repo `branding/logo.svg`.
class IkamvaLogo extends StatelessWidget {
  const IkamvaLogo({
    super.key,
    this.height = 72,
    this.width,
    this.borderRadius,
  });

  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final child = Image.asset(
      AppAssets.logoPng,
      height: height,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Ikamva Lam',
    );
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }
}
