import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_typography.dart';

class GreetingHeader extends StatelessWidget {
  final String name;

  const GreetingHeader({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.of(context);
    return Text('Hi, $name! 👋', style: typography.headlineLarge);
  }
}
