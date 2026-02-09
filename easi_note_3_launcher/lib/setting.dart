import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  static const _fastbootKey = 'fastboot';
  static const _noAnimationKey = 'no_animation';

  /// 获取 fastboot
  static Future<bool> getFastboot() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_fastbootKey) ?? false;
  }

  /// 设置 fastboot
  static Future<void> setFastboot(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fastbootKey, value);
  }

  /// 获取 no_animation
  static Future<bool> getNoAnimation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_noAnimationKey) ?? false;
  }

  /// 设置 no_animation
  static Future<void> setNoAnimation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_noAnimationKey, value);
  }
}