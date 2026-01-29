import 'package:flutter/material.dart';
import '../../core/utils.dart';

class PeerAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool isOnline;
  final bool showOnlineIndicator;

  const PeerAvatar({
    Key? key,
    required this.name,
    this.size = 40,
    this.isOnline = false,
    this.showOnlineIndicator = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: size / 2,
          backgroundColor: ColorUtils.getAvatarColor(name),
          child: Text(
            TextUtils.getInitials(name),
            style: TextStyle(
              color: Colors.white,
              fontSize: size / 2.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (showOnlineIndicator && isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size / 4,
              height: size / 4,
              decoration: BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
