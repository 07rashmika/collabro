import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/connections/domain/repos/connections_repo.dart';

import '../../domain/entities/app_notification.dart';
import '../../domain/repos/notifications_repo.dart';

part 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationsRepo notificationsRepo;
  final ConnectionsRepo connectionsRepo;

  NotificationsCubit({
    required this.notificationsRepo,
    required this.connectionsRepo,
  }) : super(const NotificationsInitial());

  Future<void> load() async {
    emit(const NotificationsLoading());
    try {
      final page = await notificationsRepo.getNotifications();
      emit(NotificationsLoaded(page));
    } catch (e) {
      emit(NotificationsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> markAllRead() async {
    await notificationsRepo.markAllRead();
  }

  Future<void> respondToRequest(
    String connectionId, {
    required bool accept,
  }) async {
    if (accept) {
      await connectionsRepo.accept(connectionId);
    } else {
      await connectionsRepo.decline(connectionId);
    }
    await load();
  }
}
