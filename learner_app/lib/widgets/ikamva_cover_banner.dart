import 'package:flutter/material.dart';

import '../branding/app_assets.dart';
import '../theme/ikamva_colors.dart';

/// Social / README-style cover art (1200×630 raster).
class IkamvaCoverBanner extends StatelessWidget {
  const IkamvaCoverBanner({super.key, this.borderRadius});

  final BorderRadius? borderRadius;

  static const double _aspect = 1200 / 630;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(20);
    final border = Border.all(
      color: context.ikamvaColors.textSecondary.withValues(alpha: 0.2),
    );
    return AspectRatio(
      aspectRatio: _aspect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: border,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Image.asset(
            AppAssets.logoPng,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            semanticLabel: 'Ikamva Lam — cover',
          ),
        ),
      ),
    );
  }
}
