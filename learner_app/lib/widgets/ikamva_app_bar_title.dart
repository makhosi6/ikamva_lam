import 'package:flutter/material.dart';

import 'ikamva_logo.dart';

/// Logo + truncated title for AppBar `title` slot.
class IkamvaAppBarTitle extends StatelessWidget {
  const IkamvaAppBarTitle({
    super.key,
    required this.title,
    this.logoHeight = 34,
  });

  final String title;
  final double logoHeight;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge;
    return Row(
      children: [
        IkamvaLogo(height: logoHeight),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
