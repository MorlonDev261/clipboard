import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The Deganeo logo on a white disc (it is drawn for light backgrounds).
class DeganeoIcon extends StatelessWidget {
  const DeganeoIcon({this.size = 22, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.09),
        child: SvgPicture.asset(
          'assets/deganeo/logo-Deganeo.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
