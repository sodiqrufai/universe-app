class ApiConfig {
  static const bool useProduction = true;
  static const String baseUrl = useProduction
      ? 'https://universe-app-w4cc.onrender.com'
      : 'http://localhost:3000';
}
