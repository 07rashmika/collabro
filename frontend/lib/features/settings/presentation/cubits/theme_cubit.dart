import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:frontend/core/network/secure_storage_keys.dart';

const _lightValue = 'light';
const _darkValue = 'dark';

class ThemeCubit extends Cubit<ThemeMode> {
  final FlutterSecureStorage storage;

  ThemeCubit({required this.storage}) : super(ThemeMode.dark) {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final saved = await storage.read(key: SecureStorageKeys.themeMode);
    if (saved == _lightValue) emit(ThemeMode.light);
  }

  Future<void> setLightMode(bool isLight) async {
    emit(isLight ? ThemeMode.light : ThemeMode.dark);
    await storage.write(
      key: SecureStorageKeys.themeMode,
      value: isLight ? _lightValue : _darkValue,
    );
  }
}
