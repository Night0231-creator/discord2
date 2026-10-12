import 'package:flutter_test/flutter_test.dart';
import 'package:veylor/api_endpoint.dart';
void main() {
  test('HTTPS accepted and normalized', (){
    expect(validateApiEndpoint(' https://example.org/ '),'https://example.org');
    expect(validateApiEndpoint('https://example.org:8443'),'https://example.org:8443');
  });
  test('local HTTP accepted', (){
    expect(validateApiEndpoint('http://127.0.0.1:8080'),'http://127.0.0.1:8080');
  });
  test('remote HTTP and unsafe URLs rejected', (){
    expect(()=>validateApiEndpoint('http://192.168.1.7:8080'),throwsFormatException);
    expect(()=>validateApiEndpoint('https://user:pass@example.org'),throwsFormatException);
    expect(()=>validateApiEndpoint('https://example.org/path'),throwsFormatException);
    expect(()=>validateApiEndpoint('not-a-url'),throwsFormatException);
  });
}
