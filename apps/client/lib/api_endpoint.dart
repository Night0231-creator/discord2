/// Only HTTPS may be used with remote hosts to protect bearer credentials.
String validateApiEndpoint(String input) {
  final uri=Uri.tryParse(input.trim());
  if(uri==null || !uri.hasAuthority || uri.host.isEmpty ||
      !['http','https'].contains(uri.scheme) || uri.userInfo.isNotEmpty ||
      uri.hasQuery || uri.hasFragment || (uri.path.isNotEmpty && uri.path!='/')) {
    throw const FormatException('Use https://api.seudominio.com');
  }
  if(uri.scheme=='http' &&
      !['localhost','127.0.0.1','::1'].contains(uri.host) &&
      !const bool.fromEnvironment('ALLOW_INSECURE_DEV_API')) {
    throw const FormatException('Endereços remotos exigem HTTPS.');
  }
  return uri.origin;
}
