import 'dart:convert';
import 'package:wai_life_assistant/core/services/ai_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AssistantResponse — structured response from Gemini
// ─────────────────────────────────────────────────────────────────────────────

class HighlightChip {
  final String label;
  final String value;
  final String color; // green | red | amber | blue

  const HighlightChip({
    required this.label,
    required this.value,
    required this.color,
  });

  factory HighlightChip.fromJson(Map<String, dynamic> j) => HighlightChip(
        label: j['label'] as String? ?? '',
        value: j['value'] as String? ?? '',
        color: j['color'] as String? ?? 'blue',
      );
}

class DeepLink {
  final String label;
  final int tab;
  final String? subTab;

  const DeepLink({required this.label, required this.tab, this.subTab});

  factory DeepLink.fromJson(Map<String, dynamic> j) {
    final tabStr = (j['tab'] as String? ?? '').toLowerCase();
    return DeepLink(
      label: j['label'] as String? ?? 'Open',
      tab: _tabIndex(tabStr),
      subTab: j['sub_tab'] as String?,
    );
  }

  static int _tabIndex(String tag) => switch (tag) {
        'wallet' => 1,
        'pantry' => 2,
        'planit' => 3,
        _ => 0,
      };

  String get emoji => switch (tab) {
        1 => '₹',
        2 => '🥗',
        3 => '📅',
        _ => '→',
      };
}

class AssistantResponse {
  final String answer;
  final List<HighlightChip> highlights;
  final List<String> suggestions;
  final List<DeepLink> deepLinks;
  final double confidence;

  const AssistantResponse({
    required this.answer,
    this.highlights = const [],
    this.suggestions = const [],
    this.deepLinks = const [],
    this.confidence = 1.0,
  });

  static AssistantResponse fromResult(AIParseResult result) {
    if (!result.success || result.data == null) {
      return AssistantResponse(
        answer: result.error ?? 'Sorry, I couldn\'t fetch an answer right now.',
      );
    }
    return _fromMap(result.data!);
  }

  static AssistantResponse _fromMap(Map<String, dynamic> data) {
    final highlights = (data['highlights'] as List? ?? [])
        .map((h) => HighlightChip.fromJson(h as Map<String, dynamic>))
        .toList();
    final suggestions = (data['suggestions'] as List? ?? [])
        .map((s) => s as String)
        .toList();
    final deepLinks = (data['deep_links'] as List? ?? [])
        .map((l) => DeepLink.fromJson(l as Map<String, dynamic>))
        .toList();
    return AssistantResponse(
      answer: data['answer'] as String? ?? '',
      highlights: highlights,
      suggestions: suggestions,
      deepLinks: deepLinks,
      confidence: (data['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  static AssistantResponse fromRaw(String raw) {
    // Try JSON parse first
    try {
      final jsonStart = raw.indexOf('{');
      final jsonEnd = raw.lastIndexOf('}');
      if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
        final data = jsonDecode(raw.substring(jsonStart, jsonEnd + 1)) as Map<String, dynamic>;
        return _fromMap(data);
      }
    } catch (_) {}

    // Fallback: plain text with [GO:tag] parsing
    final tagPattern = RegExp(r'\[GO:(wallet|pantry|planit)\]', caseSensitive: false);
    final deepLinks = tagPattern
        .allMatches(raw)
        .map((m) => DeepLink.fromJson({'label': 'Open ${m.group(1)}', 'tab': m.group(1)!.toLowerCase()}))
        .toList();

    return AssistantResponse(
      answer: raw.replaceAll(tagPattern, '').trim(),
      deepLinks: deepLinks,
    );
  }

  bool get isEmpty => answer.isEmpty;
}
