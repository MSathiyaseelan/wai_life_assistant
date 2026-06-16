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
        // Extract raw error string (for logging + mapping)
        String rawErr;
        if (raw is Map<String, dynamic>) {
          rawErr = raw['error'] as String? ?? raw['message'] as String? ?? 'Server error ($status)';
        } else if (raw is String && raw.isNotEmpty) {
          try {
            final decoded = jsonDecode(raw) as Map<String, dynamic>;
            rawErr = decoded['error'] as String? ?? decoded['message'] as String? ?? 'Server error ($status)';
          } catch (_) {
            rawErr = raw.length > 200 ? '${raw.substring(0, 200)}…' : raw;
          }
        } else {
          rawErr = 'Server error ($status)';
        }
        debugPrint('[AIParser] non-200 error: $rawErr');
        return AIParseResult.error(_friendlyError(rawErr));
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
        return AIParseResult.error('Unexpected response format. Please try again.');
      }

      return AIParseResult.fromJson(json);
    } on FunctionException catch (e) {
      final details = e.details;
      String rawErr;
      if (details is Map) {
        rawErr = details['error'] as String? ?? details['message'] as String? ?? 'Server error (${e.status})';
      } else {
        rawErr = e.reasonPhrase ?? 'Server error (${e.status})';
      }
      debugPrint('[AIParser] FunctionException status=${e.status} raw=$rawErr');
      return AIParseResult.error(_friendlyError(rawErr));
    } catch (e, st) {
      debugPrint('[AIParser] EXCEPTION type=${e.runtimeType}');
      debugPrint('[AIParser] EXCEPTION message=$e');
      debugPrint('[AIParser] EXCEPTION stacktrace=$st');
      return AIParseResult.error(_friendlyError(e.toString()));
    }
  }

  /// Maps any raw Gemini/server/network error to a short, user-friendly string.
  /// Raw errors are preserved in debugPrint; callers never see technical details.
  static String _friendlyError(String? raw) {
    if (raw == null || raw.isEmpty) {
      return 'Something went wrong. Please try again.';
    }
    final msg = raw.toLowerCase();

    // Quota / rate limit (Gemini 429 / RESOURCE_EXHAUSTED)
    if (msg.contains('quota_exceeded') || msg.contains('quota') ||
        msg.contains('resource_exhausted') || msg.contains('rate_limit') ||
        msg.contains('rate limit') || msg.contains('429') ||
        msg.contains('you exceeded')) {
      return 'AI request limit reached. Please wait a moment and try again.';
    }

    // Service overloaded / busy (Gemini 503)
    if (msg.contains('service_overloaded') || msg.contains('overloaded') ||
        msg.contains('503') || msg.contains('high demand') ||
        msg.contains('capacity') || msg.contains('too many requests')) {
      return 'AI service is busy right now. Please try again in a few seconds.';
    }

    // Auth / API key issues (401 / 403)
    if (msg.contains('api_key_invalid') || msg.contains('unauthenticated') ||
        msg.contains('permission_denied') || msg.contains('401') ||
        msg.contains('403') || msg.contains('unauthorized')) {
      return 'AI service is not available right now. Please try again later.';
    }

    // Timeout
    if (msg.contains('timeout') || msg.contains('timed out') ||
        msg.contains('deadline exceeded')) {
      return 'Request timed out. Please check your connection and try again.';
    }

    // Network / no internet
    if (msg.contains('socketexception') || msg.contains('no address') ||
        msg.contains('failed host lookup') || msg.contains('network is unreachable')) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Empty / malformed AI response
    if (msg.contains('empty response') || msg.contains('no candidates') ||
        msg.contains('invalid json') || msg.contains('json parse')) {
      return 'AI returned an unexpected response. Please try rephrasing.';
    }

    // Prompt not configured
    if (msg.contains('no active prompt') || msg.contains('no prompt found') ||
        msg.contains('not configured') || msg.contains('404')) {
      return 'This AI feature is not yet available. Please try again later.';
    }

    // Generic server errors (500 / 502 / server_error / gemini_error_*)
    if (msg.contains('server_error') || msg.contains('server error') ||
        msg.contains('502') || msg.contains('500') ||
        msg.contains('gemini_error')) {
      return 'AI service encountered an error. Please try again.';
    }

    // Fallback
    return 'Something went wrong. Please try again.';
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
