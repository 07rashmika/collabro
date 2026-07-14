import 'package:flutter/material.dart';

/// Shows a lightweight snackbar for features that don't exist yet, so
/// tapping unbuilt affordances is honest instead of dead silent or faked.
void showComingSoonSnackBar(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$feature is coming soon.')),
  );
}
