import 'package:flutter/material.dart';
import '../../core/app_config.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyStateWidget({
    Key? key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingLarge * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: AppTheme.paddingLarge),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fontSizeLarge,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.paddingSmall),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeMedium,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTheme.paddingLarge),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}