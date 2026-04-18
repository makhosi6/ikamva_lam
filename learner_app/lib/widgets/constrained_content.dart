import 'package:flutter/material.dart';

/// Single-column layout for tablets: readable line length, centered.
class ConstrainedContent extends StatelessWidget {
  const ConstrainedContent({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    /// If false, skips [SingleChildScrollView] so flex children get bounded height.
    this.scrollable = true,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );
    if (scrollable) {
      return Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: padding,
          child: content,
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: padding,
        child: content,
      ),
    );
  }
}
