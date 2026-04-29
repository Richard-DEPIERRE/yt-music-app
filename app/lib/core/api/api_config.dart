class ApiConfig {
  ApiConfig({
    required this.baseUrl,
    required this.cfAccessClientId,
    required this.cfAccessClientSecret,
  });

  final String baseUrl;
  final String cfAccessClientId;
  final String cfAccessClientSecret;

  bool get isComplete =>
      baseUrl.isNotEmpty &&
      cfAccessClientId.isNotEmpty &&
      cfAccessClientSecret.isNotEmpty;
}
