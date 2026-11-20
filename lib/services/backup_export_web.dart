import 'dart:js_interop';

@JS('document.createElement')
external _JSHTMLElement _createElement(String tagName);

@JS('document.body.appendChild')
external void _appendChild(_JSHTMLElement node);

@JS('document.body.removeChild')
external void _removeChild(_JSHTMLElement node);

extension type _JSHTMLElement(JSObject _) implements JSObject {
  external set href(String value);
  external set download(String value);
  external void click();
}

Future<String> exportCmonuFileImpl({required String fileName, required String jsonContent}) async {
  final encoded = Uri.encodeComponent(jsonContent);
  final dataUri = 'data:application/json;charset=utf-8,$encoded';
  final anchor = _createElement('a')
    ..href = dataUri
    ..download = fileName;
  _appendChild(anchor);
  anchor.click();
  _removeChild(anchor);
  return 'Downloaded $fileName';
}

Future<String> readCmonuFileFromPathImpl(String filePath) async {
  throw UnsupportedError('Direct file paths are not used on Web.');
}
