import 'package:flutter/material.dart';

class HubCarouselChevron extends StatelessWidget {
  const HubCarouselChevron({
    super.key,
    required this.icon,
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Semantics(
          label: label,
          button: true,
          enabled: enabled,
          child: SizedBox(
            width: 28,
            child: Center(
              child: Icon(
                icon,
                size: 28,
                color: enabled
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
