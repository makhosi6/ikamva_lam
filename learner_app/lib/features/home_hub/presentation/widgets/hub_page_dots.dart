import 'package:flutter/material.dart';

class HubPageDots extends StatelessWidget {
  const HubPageDots({
    super.key,
    required this.count,
    required this.index,
    required this.color,
    required this.inactive,
  });

  final int count;
  final int index;
  final Color color;
  final Color inactive;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox(height: 12);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == index ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? color : inactive,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
      ],
    );
  }
}
