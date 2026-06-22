import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent');
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': 'AQ.Ab8RN6LqVKBnz8ZLBDJ-ALyIuvce_CcSGQsgimV6RYIKVw0X2g'
    },
    body: jsonEncode({
      'contents': [
        {'parts': [{'text': 'hi'}]}
      ]
    })
  );
  print('Status code: ${response.statusCode}');
  print(response.body);
}
