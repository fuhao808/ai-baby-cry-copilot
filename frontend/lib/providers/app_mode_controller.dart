import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppModeState {
  const AppModeState({required this.isTestMode});

  final bool isTestMode;

  AppModeState copyWith({bool? isTestMode}) {
    return AppModeState(isTestMode: isTestMode ?? this.isTestMode);
  }
}

class AppModeController extends StateNotifier<AppModeState> {
  AppModeController() : super(const AppModeState(isTestMode: false)) {
    _load();
  }

  static const _testModeKey = 'app_test_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      isTestMode: prefs.getBool(_testModeKey) ?? false,
    );
  }

  Future<void> toggleTestMode() async {
    final next = !state.isTestMode;
    state = state.copyWith(isTestMode: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_testModeKey, next);
  }
}

final appModeProvider =
    StateNotifierProvider<AppModeController, AppModeState>(
  (ref) => AppModeController(),
);
