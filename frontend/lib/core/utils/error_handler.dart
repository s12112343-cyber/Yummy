/// Error Handler احترافي لـ Yummy App
/// هذا الملف مسؤول عن معالجة جميع الأخطاء بطريقة احترافية
library;

import 'package:flutter/foundation.dart';

class AppException implements Exception {
  final String message;
  final String? errorCode;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppException({
    required this.message,
    this.errorCode,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => message;
}

/// رسائل الأخطاء الموحدة - لا نعرض التفاصيل الداخلية
class ErrorMessages {
  // مشاكل الاتصال والشبكة
  static const String networkTimeout =
      'انقطع الاتصال بالإنترنت. حاول مرة أخرى.';
  static const String connectionError =
      'خطأ في الاتصال بالسيرفر. تأكد من اتصالك بالإنترنت.';
  static const String serverError = 'حدث خطأ في السيرفر. حاول لاحقاً.';

  // مشاكل التحقق والبيانات
  static const String invalidEmail = 'البريد الإلكتروني غير صحيح.';
  static const String weakPassword = 'كلمة المرور ضعيفة جداً.';
  static const String invalidCredentials =
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
  static const String userNotFound = 'المستخدم غير موجود.';
  static const String userAlreadyExists = 'البريد الإلكتروني مسجل مسبقاً.';

  // مشاكل التحديث والحفظ
  static const String failedToSave = 'فشل حفظ البيانات. حاول مرة أخرى.';
  static const String failedToUpdate = 'فشل تحديث البيانات. حاول مرة أخرى.';
  static const String failedToLoad = 'فشل تحميل البيانات. حاول مرة أخرى.';

  // مشاكل الملفات
  static const String fileTooLarge = 'الملف كبير جداً (الحد الأقصى 5MB).';
  static const String invalidFileType = 'نوع الملف غير مدعوم.';
  static const String failedToUploadFile = 'فشل رفع الملف. حاول مرة أخرى.';

  // مشاكل التوثيق والتصريح
  static const String tokenExpired = 'انتهت صلاحية الجلسة. سجل دخولك مجدداً.';
  static const String unauthorized = 'غير مصرح لك بهذا الإجراء.';

  // مشاكل عامة
  static const String unknownError = 'حدث خطأ. حاول لاحقاً.';
  static const String tryAgainLater = 'الخدمة غير متوفرة الآن. حاول لاحقاً.';
}

/// معالج الأخطاء - يحول الأخطاء الحقيقية إلى رسائل احترافية
class ErrorHandler {
  /// معالجة أخطاء HTTP
  static String handleHttpError(dynamic error, {int? statusCode}) {
    if (error is TimeoutException) {
      return ErrorMessages.networkTimeout;
    }

    if (statusCode != null) {
      switch (statusCode) {
        case 400:
          return ErrorMessages.invalidCredentials;
        case 401:
          return ErrorMessages.unauthorized;
        case 403:
          return ErrorMessages.unauthorized;
        case 404:
          return ErrorMessages.userNotFound;
        case 409:
          return ErrorMessages.userAlreadyExists;
        case 413:
          return ErrorMessages.fileTooLarge;
        case 500:
          return ErrorMessages.serverError;
        case 503:
          return ErrorMessages.tryAgainLater;
        default:
          return ErrorMessages.unknownError;
      }
    }

    return ErrorMessages.connectionError;
  }

  /// معالجة أخطاء التحقق من الصحة
  static String handleValidationError(String field) {
    switch (field.toLowerCase()) {
      case 'email':
        return ErrorMessages.invalidEmail;
      case 'password':
        return ErrorMessages.weakPassword;
      default:
        return 'بيانات غير صحيحة.';
    }
  }

  /// معالجة أخطاء الملفات
  static String handleFileError(String errorType) {
    switch (errorType.toLowerCase()) {
      case 'too_large':
        return ErrorMessages.fileTooLarge;
      case 'invalid_type':
        return ErrorMessages.invalidFileType;
      case 'upload_failed':
        return ErrorMessages.failedToUploadFile;
      default:
        return 'حدث خطأ مع الملف.';
    }
  }

  /// تسجيل الأخطاء الداخلية (development فقط)
  static void logError(String context, dynamic error, StackTrace? stackTrace) {
    if (kDebugMode) {
      print('❌ Error in $context: $error');
      if (stackTrace != null) {
        print('Stack Trace: $stackTrace');
      }
    }
  }

  /// رمية استثناء احترافي
  static Never throwAppException(
    String message, {
    String? errorCode,
    dynamic originalError,
    StackTrace? stackTrace,
  }) {
    throw AppException(
      message: message,
      errorCode: errorCode,
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
