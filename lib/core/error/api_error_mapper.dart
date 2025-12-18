import 'package:dio/dio.dart';
import 'api_exception.dart';
import 'ui_error_message.dart';

class ApiErrorMapper {
  static ApiException map(DioException error) {
    // Network / timeout errors
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return ApiException(message: UiErrorMessage.timeout);
    }

    if (error.type == DioExceptionType.connectionError) {
      return ApiException(message: UiErrorMessage.network);
    }

    final statusCode = error.response?.statusCode;

    switch (statusCode) {
      case 400:
        return ApiException(
          message: _extractMessage(error) ?? UiErrorMessage.unknown,
          statusCode: 400,
        );
      case 401:
        return ApiException(
          message: UiErrorMessage.unauthorized,
          statusCode: 401,
        );
      case 403:
        return ApiException(message: UiErrorMessage.forbidden, statusCode: 403);
      case 404:
        return ApiException(message: UiErrorMessage.notFound, statusCode: 404);
      case 500:
      case 502:
      case 503:
        return ApiException(
          message: UiErrorMessage.server,
          statusCode: statusCode,
        );
      default:
        return ApiException(
          message: UiErrorMessage.unknown,
          statusCode: statusCode,
        );
    }
  }

  static String? _extractMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'];
    }
    return null;
  }
}
