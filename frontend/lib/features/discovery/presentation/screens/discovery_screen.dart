import 'package:flutter/material.dart';

import 'package:frontend/core/widgets/coming_soon_screen.dart';

class DiscoveryScreen extends StatelessWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Discovery',
      icon: Icons.explore_outlined,
    );
  }
}
