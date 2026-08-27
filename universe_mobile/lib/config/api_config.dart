class ApiConfig {
  // Switch this one line to flip between local development and the live server.
  static const bool useProduction = true;

  static const String _localUrl = '${ApiConfig.baseUrl}';
  static const String _productionUrl = 'https://universe-app-w4cc.onrender.com';

  static String get baseUrl => useProduction ? _productionUrl : _localUrl;
}