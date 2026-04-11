class AppConfig {
  // JETKIZ RESTAURANT APP
  // Физическое Android-устройство через USB:
  // backend локально на ПК, доступ через adb reverse tcp:3000 tcp:3000
  static const String baseUrl = 'http://127.0.0.1:3000';

  // Для эмулятора Android:
  // static const String baseUrl = 'http://10.0.2.2:3000';

  // Для Wi-Fi теста:
  // static const String baseUrl = 'http://192.168.1.100:3000';
}