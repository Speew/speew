import 'package:flutter/material.dart';
import '../../core/app_config.dart';
import '../../core/utils.dart';

class ConnectionStatusBar extends StatelessWidget {
  final String? statusMessage;
  final bool isDiscovering;

  const ConnectionStatusBar({
    Key? key,
    this.statusMessage,
    this.isDiscovering = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (statusMessage == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(
            color: Colors.blue.shade100,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (isDiscovering)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          else
            const Icon(
              Icons.info_outline,
              size: 16,
              color: Colors.blue,
            ),
          const SizedBox(width: AppTheme.paddingMedium),
          Expanded(
            child: Text(
              statusMessage!,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeSmall,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConnectionStatusIndicator extends StatelessWidget {
  final bool isConnected;
  final String? statusText;

  const ConnectionStatusIndicator({
    Key? key,
    required this.isConnected,
    this.statusText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isConnected ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        if (statusText != null) ...[
          const SizedBox(width: 6),
          Text(
            statusText!,
            style: TextStyle(
              fontSize: AppTheme.fontSizeSmall,
              color: isConnected ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ],
    );
  }
}
