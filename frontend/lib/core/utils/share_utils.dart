import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareText(
  BuildContext context, {
  required String text,
  String? subject,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
  await SharePlus.instance.share(
    ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
  );
}
