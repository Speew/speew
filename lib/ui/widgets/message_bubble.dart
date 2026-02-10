import 'package:flutter/material.dart';
import '../../models/message.dart';
import '../../core/utils.dart';
import '../../core/app_config.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final VoidCallback? onLongPress;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(
            vertical: AppTheme.paddingSmall / 2,
            horizontal: AppTheme.paddingMedium,
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 14,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isMe
                ? const Color(AppTheme.myMessageColor)
                : const Color(AppTheme.peerMessageColor),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppTheme.radiusMedium),
              topRight: const Radius.circular(AppTheme.radiusMedium),
              bottomLeft: isMe
                  ? const Radius.circular(AppTheme.radiusMedium)
                  : const Radius.circular(0),
              bottomRight: isMe
                  ? const Radius.circular(0)
                  : const Radius.circular(AppTheme.radiusMedium),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              const Text(
                message.content,
                style: TextStyle(
                  color: isMe
                      ? const Color(AppTheme.myMessageTextColor)
                      : const Color(AppTheme.peerMessageTextColor),
                  fontSize: AppTheme.fontSizeMedium,
                ),
              ),
              
              const SizedBox(height: 4),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    DateTimeUtils.formatChatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeSmall,
                      color: isMe
                          ? Colors.white70
                          : Colors.black54,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;

    if (message.isSent) {
      icon = Icons.check;
      color = Colors.white70;
    } else {
      icon = Icons.access_time;
      color = Colors.white54;
    }

    return const Icon(
      icon,
      size: 14,
      color: color,
    );
  }
}