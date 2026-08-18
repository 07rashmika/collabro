import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/utils/snackbar_utils.dart';
import 'package:frontend/core/widgets/connect_button.dart';

import 'cubits/connections_cubit.dart';

Future<void> handleConnectPress(
  BuildContext context,
  String userId,
  ConnectStatus status,
) async {
  try {
    final cubit = context.read<ConnectionsCubit>();
    if (status == .requested) {
      await cubit.cancelRequest(userId);
    } else {
      await cubit.sendRequest(userId);
    }
  } catch (e) {
    if (!context.mounted) return;
    showErrorSnackBar(context);
  }
}
