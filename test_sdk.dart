import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  final model = GenerativeModel(
    model: 'gemini-flash-latest',
    apiKey: 'AQ.Ab8RN6JqFLFQR2dZ2_XcycdjiHGl6GG0KYqgFHSuCewsTVk8Rg',
  );
  try {
    final response = await model.generateContent([Content.text('hi')]);
    print('Success: ${response.text}');
  } catch (e) {
    print('Error: $e');
  }
}
