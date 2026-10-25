import 'package:shared_preferences/shared_preferences.dart';

/// Small device-local preferences (currently just Data Saver).
///
/// Data Saver is read synchronously by the feed's URL builder, so
/// the value is cached in a static field at startup ([load]) and
/// updated in place when the user flips the Settings toggle. It
/// only affects players created after the change.
class PrefsService {
  PrefsService._();

  static const _kDataSaver = 'chaska_data_saver';

  static bool dataSaver = false;

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      dataSaver = p.getBool(_kDataSaver) ?? false;
    } catch (_) {
      dataSaver = false;
    }
  }

  static Future<void> setDataSaver(bool value) async {
    dataSaver = value;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kDataSaver, value);
    } catch (_) {}
  }
}
