import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=AQ.Ab8RN6JqFLFQR2dZ2_XcycdjiHGl6GG0KYqgFHSuCewsTVk8Rg');
  final response = await http.get(url);
  final data = jsonDecode(response.body);
  for (var model in data['models']) {
    print(model['name']);
  }
}
