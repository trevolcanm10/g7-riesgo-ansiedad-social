/// Build-time APIM configuration. No real subscription keys belong in source.
class ApiGatewayConfig {
  final String baseUrl;
  final String subscriptionKey;
  const ApiGatewayConfig({this.baseUrl = '', this.subscriptionKey = ''});

  bool get enabled => baseUrl.trim().isNotEmpty;
  String get origin => baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  String get usersOrigin => '$origin/u';
  String get registration => '$usersOrigin/users';
  String get login => '$usersOrigin/users/login';
  String get evaluation => '$origin/re/risk-evaluations';

  /// Never forward the APIM key to localhost or a different server/path.
  Map<String, String> headersFor(String url) {
    if (!enabled) return {};
    final gateway = Uri.tryParse(origin);
    if (gateway == null ||
        gateway.scheme != 'https' ||
        gateway.host.isEmpty ||
        gateway.userInfo.isNotEmpty ||
        gateway.hasQuery ||
        gateway.hasFragment) {
      throw const FormatException(
        'APIM_BASE_URL debe ser una URL HTTPS válida.',
      );
    }
    final target = Uri.parse(url);
    final prefix = gateway.path;
    final matchesPath =
        prefix.isEmpty ||
        target.path == prefix ||
        target.path.startsWith('$prefix/');
    if (target.scheme != gateway.scheme ||
        target.host != gateway.host ||
        target.port != gateway.port ||
        !matchesPath) {
      return {};
    }
    if (subscriptionKey.trim().isEmpty) {
      throw const FormatException(
        'Falta APIM_SUBSCRIPTION_KEY en la configuración.',
      );
    }
    return {'Ocp-Apim-Subscription-Key': subscriptionKey.trim()};
  }
}
