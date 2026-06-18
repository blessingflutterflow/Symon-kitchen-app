import 'package:flutter/material.dart';

/// Centers content at max 520 px on wide screens (web/tablet).
/// Passes the full viewport height down so Expanded/Spacer still work.
class NarrowBody extends StatelessWidget {
  const NarrowBody({super.key, required this.child, this.maxWidth = 520});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: constraints.maxWidth.clamp(0.0, maxWidth),
          height: constraints.maxHeight,
          child: child,
        ),
      ),
    );
  }
}
