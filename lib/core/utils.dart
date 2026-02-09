import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_config.dart';

class DateTimeUtils {
  static String formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Agora';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m atrás';
    } else if (difference.inHours < 24) {
      return DateFormat(AppConstants.dateFormatShort).format(dateTime);
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d atrás';
    } else {
      return DateFormat(AppConstants.dateFormatMedium).format(dateTime);
    }
  }

  static String formatLastSeen(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Online agora';
    } else if (difference.inMinutes < 60) {
      return 'Há ${difference.inMinutes} minutos';
    } else if (difference.inHours < 24) {
      return 'Há ${difference.inHours} horas';
    } else if (difference.inDays < 7) {
      return 'Há ${difference.inDays} dias';
    } else {
      return DateFormat(AppConstants.dateFormatLong).format(dateTime);
    }
  }

  static String formatChatTime(DateTime dateTime) {
    return DateFormat(AppConstants.dateFormatShort).format(dateTime);
  }

  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return isSameDay(date, yesterday);
  }
}

class ValidationUtils {
  static bool isValidName(String name) {
    return name.trim().isNotEmpty && name.trim().length >= 2;
  }

  static bool isValidMessage(String message) {
    return message.trim().isNotEmpty &&
        message.length <= AppConfig.maxMessageLength;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nome é obrigatório';
    }
    if (value.trim().length < 2) {
      return 'Nome deve ter pelo menos 2 caracteres';
    }
    return null;
  }

  static String? validateMessage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mensagem não pode estar vazia';
    }
    if (value.length > AppConfig.maxMessageLength) {
      return 'Mensagem muito longa (máx: ${AppConfig.maxMessageLength} caracteres)';
    }
    return null;
  }
}

class ColorUtils {
  static Color getStatusColor(String status) {
    switch (status) {
      case AppConstants.statusConnected:
        return const Color(AppTheme.onlineColor);
      case AppConstants.statusDisconnected:
        return const Color(AppTheme.offlineColor);
      case AppConstants.statusConnecting:
        return const Color(AppTheme.connectingColor);
      default:
        return const Color(AppTheme.offlineColor);
    }
  }

  static Color getAvatarColor(String seed) {
    final colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
    ];

    final hash = seed.hashCode.abs();
    return colors[hash % colors.length];
  }

  static Color darken(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  static Color lighten(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }
}

class TextUtils {
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  static String getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  static int countWords(String text) {
    return text.trim().split(RegExp(r'\s+')).length;
  }

  static String sanitize(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}

class UiUtils {
  static void showSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: backgroundColor,
        action: action,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showErrorSnackBar(BuildContext context, String message) {
    showSnackBar(
      context,
      message,
      backgroundColor: const Color(AppTheme.errorColor),
    );
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    showSnackBar(
      context,
      message,
      backgroundColor: const Color(AppTheme.successColor),
    );
  }

  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: isDangerous
                ? ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppTheme.errorColor),
                  )
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(message),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static void hideLoadingDialog(BuildContext context) {
    Navigator.pop(context);
  }

  static void unfocus(BuildContext context) {
    FocusScope.of(context).unfocus();
  }
}

class DeviceUtils {
  static bool isAndroid(BuildContext context) {
    return Theme.of(context).platform == TargetPlatform.android;
  }

  static bool isIOS(BuildContext context) {
    return Theme.of(context).platform == TargetPlatform.iOS;
  }

  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static bool isSmallScreen(BuildContext context) {
    return getScreenWidth(context) < 375;
  }

  static bool isLargeScreen(BuildContext context) {
    return getScreenWidth(context) > 600;
  }
}

class DebugUtils {
  static void log(String message, {String? tag}) {
    if (AppConfig.enableDebugLogs) {
      final timestamp = DateTime.now().toIso8601String();
      final prefix = tag != null ? '[$tag]' : '[DEBUG]';
      print('$timestamp $prefix $message');
    }
  }

  static void logError(String message, {Object? error, StackTrace? stackTrace}) {
    if (AppConfig.enableDebugLogs) {
      final timestamp = DateTime.now().toIso8601String();
      print('$timestamp [ERROR] $message');
      if (error != null) {
        print('Error: $error');
      }
      if (stackTrace != null) {
        print('StackTrace: $stackTrace');
      }
    }
  }
}
