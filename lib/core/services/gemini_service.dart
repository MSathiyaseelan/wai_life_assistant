import 'dart:convert';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// GeminiService — calls Gemini 1.5 Flash via REST
// Replace _apiKey with your key from https://aistudio.google.com/app/apikey
// ─────────────────────────────────────────────────────────────────────────────

class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  // TODO: replace with your Gemini API key
  static const _apiKey = 'YOUR_GEMINI_API_KEY';

  static const _model = 'gemini-1.5-flash-latest';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static const _systemInstruction =
      'You are WAI, a smart personal life assistant embedded in a mobile app. '
      'Answer the user\'s question in 2–4 sentences using ONLY the data provided. '
      'Be friendly, direct, and use ₹ for currency. '
      'If the answer involves wallet data, end with exactly [GO:wallet]. '
      'If pantry/grocery/food data, end with [GO:pantry]. '
      'If tasks/bills/planning data, end with [GO:planit]. '
      'Use at most ONE action tag. Do NOT include tags if irrelevant.';

  Future<String> ask(
    String contextBlock,
    String question, {
    String? systemPrompt,
  }) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY') {
      return 'Please add your Gemini API key in gemini_service.dart to enable AI answers.';
    }

    final instruction = systemPrompt ?? _systemInstruction;
    final prompt = '$instruction\n\n$contextBlock\n\nQuestion: $question';

    final response = await http.post(
      Uri.parse('$_endpoint?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.4,
          'maxOutputTokens': 256,
          'topP': 0.95,
        },
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Gemini error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No candidates in Gemini response');
    }
    final parts = (candidates[0] as Map)['content']['parts'] as List;
    return (parts[0] as Map)['text'] as String? ?? '';
  }
}
