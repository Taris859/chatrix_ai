import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const String _nvidiaApiKey = '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';
  const String _modelName = 'meta/llama-3.1-70b-instruct';
  const String _baseUrl = 'https://integrate.api.nvidia.com/v1/chat/completions';

  print('Sending POST to $_baseUrl');
  final response = await http.post(
    Uri.parse(_baseUrl),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_nvidiaApiKey',
    },
    body: jsonEncode({
      'model': _modelName,
      'messages': [{"role": "user", "content": "Hello"}],
      'max_tokens': 10
    }),
  );

  print('Status: ${response.statusCode}');
  print('Body: ${response.body}');
}
