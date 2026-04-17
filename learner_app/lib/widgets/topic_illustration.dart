import 'package:flutter/material.dart';

import '../branding/app_assets.dart';

/// Topic illustration slot (TASKS §10.5) — uses brand art as generic anchor.
class TopicIllustration extends StatelessWidget {
  const TopicIllustration({super.key, required this.topic});

  final String topic;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Illustration for topic $topic',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.asset(
            AppAssets.logoPng,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}
