import 'dart:convert';

/// Lee el claim `role` del payload de un JWT **sin verificar la firma**.
///
/// Solo sirve para decidir que pantalla mostrar. La autorizacion real la hace
/// cada servicio con su propia validacion del token.
String? rolDeToken(String? token) {
  if (token == null) return null;
  final partes = token.split('.');
  if (partes.length != 3) return null;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(partes[1])));
    final json = jsonDecode(payload);
    final rol = json is Map ? json['role'] : null;
    return rol is String ? rol : null;
  } catch (_) {
    return null;
  }
}
