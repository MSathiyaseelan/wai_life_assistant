import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

class AIParser {
  static final _supabase = Supabase.instance.client;

  /// Parse plain text input
  static Future<AIParseResult> parseText({
    required String feature,
    required String subFeature,
    required String text,
    Map<String, dynamic>? context,
  }) async {
    return _invoke(
      feature: feature,
      subFeature: subFeature,
      inputType: 'text',
      body: {
        'text': text,
        'context': _buildContext(context),
      },
    );
  }

  /// Parse image input (receipt, wardrobe, pantry scan)
  static Future<AIParseResult> parseImage({
    required String feature,
    required String subFeature,
    required List<int> imageBytes,
    String mimeType = 'image/jpeg',
    Map<String, dynamic>? context,
  }) async {
    final base64Image = base64Encode(imageBytes);
    return _invoke(
      feature: feature,
      subFeature: subFeature,
      inputType: 'image',
      body: {
        'image_base64': base64Image,
        'image_mime_type': mimeType,
        'context': _buildContext(context),
      },
    );
  }

  static Map<String, dynamic> _buildContext(Map<String, dynamic>? extra) {
    final now = DateTime.now();
    return {
      'today': now.toIso8601String().split('T')[0],
      'day_of_week': _getDayName(now.weekday),
      'current_month': _getMonthName(now.month),
      'currency': 'INR',
      ...?extra,
    };
  }

  static Future<AIParseResult> _invoke({
    required String feature,
    required String subFeature,
    required String inputType,
    required Map<String, dynamic> body,
  }) async {
    try {
      debugPrint('[AIParser] invoking → feature=$feature sub=$subFeature input=$inputType');
      final response = await _supabase.functions.invoke(
        'parse',
        body: {
          'feature': feature,
          'sub_feature': subFeature,
          'input_type': inputType,
          ...body,
        },
      );

      // Check HTTP status before attempting to parse
      final status = response.status;
      final dynamic raw = response.data;

      debugPrint('[AIParser] status=$status');
      debugPrint('[AIParser] raw type=${raw.runtimeType}');
      debugPrint('[AIParser] raw=$raw');

      if (status != 200) {
        // Extract a readable error message from whatever the body is
        String errMsg;
        if (raw is Map<String, dynamic>) {
          errMsg = raw['error'] as String? ?? raw['message'] as String? ?? 'Server error ($status)';
        } else if (raw is String && raw.isNotEmpty) {
          // Try to parse as JSON error, otherwise use raw text
          try {
            final decoded = jsonDecode(raw) as Map<String, dynamic>;
            errMsg = decoded['error'] as String? ?? decoded['message'] as String? ?? 'Server error ($status)';
          } catch (_) {
            errMsg = raw.length > 120 ? '${raw.substring(0, 120)}…' : raw;
          }
        } else {
          errMsg = 'Server error ($status)';
        }
        return AIParseResult.error(errMsg);
      }

      // Edge functions sometimes return data as a raw JSON string instead of
      // an already-decoded map (especially for image payloads). Normalise here.
      final Map<String, dynamic> json;
      if (raw is Map<String, dynamic>) {
        json = raw;
      } else if (raw is String) {
        try {
          json = jsonDecode(raw) as Map<String, dynamic>;
        } on FormatException {
          return AIParseResult.error('Could not read AI response. Please try again.');
        }
      } else {
        return AIParseResult.error('Unexpected response format from AI service.');
      }

      return AIParseResult.fromJson(json);
    } on FunctionException catch (e) {
      final details = e.details;
      String errMsg;
      if (details is Map) {
        errMsg = details['error'] as String? ?? details['message'] as String? ?? 'Server error (${e.status})';
      } else {
        errMsg = e.reasonPhrase ?? 'Server error (${e.status})';
      }
      debugPrint('[AIParser] FunctionException status=${e.status} error=$errMsg');
      return AIParseResult.error(errMsg);
    } catch (e, st) {
      debugPrint('[AIParser] EXCEPTION type=${e.runtimeType}');
      debugPrint('[AIParser] EXCEPTION message=$e');
      debugPrint('[AIParser] EXCEPTION stacktrace=$st');
      return AIParseResult.error(e.toString());
    }
  }

  static String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  static String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}

class AIParseResult {
  final bool success;
  final Map<String, dynamic>? data;
  final double? confidence;
  final bool needsReview;
  final String? error;
  final Map<String, dynamic>? meta;

  AIParseResult({
    required this.success,
    this.data,
    this.confidence,
    this.needsReview = false,
    this.error,
    this.meta,
  });

  factory AIParseResult.fromJson(Map<String, dynamic> json) {
    return AIParseResult(
      success: json['success'] ?? false,
      data: json['data'],
      confidence: (json['confidence'] as num?)?.toDouble(),
      needsReview: json['needs_review'] ?? false,
      error: json['error'],
      meta: json['meta'],
    );
  }

  factory AIParseResult.error(String message) {
    return AIParseResult(success: false, error: message);
  }
}
