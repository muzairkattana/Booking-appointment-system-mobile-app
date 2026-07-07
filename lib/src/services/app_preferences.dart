import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences._();

  static final AppPreferences instance = AppPreferences._();

  SharedPreferences? _prefs;
  Future<SharedPreferences>? _prefsFuture;

  Future<SharedPreferences> get prefs async {
    if (_prefs != null) {
      return _prefs!;
    }

    _prefsFuture ??= SharedPreferences.getInstance().then((value) {
      _prefs = value;
      return value;
    });

    return _prefsFuture!;
  }
}
