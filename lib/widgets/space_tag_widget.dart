import 'package:flutter/material.dart';
import '../models/space.dart';
import '../services/spaces_service.dart';

class SpaceTagWidget extends StatelessWidget {
  final String spaceId;
  final double fontSize;
  final double horizontalPadding;
  final double verticalPadding;

  const SpaceTagWidget({
    super.key,
    required this.spaceId,
    this.fontSize = 11,
    this.horizontalPadding = 8,
    this.verticalPadding = 3,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Space?>(
      future: SpacesService.getSpaceById(spaceId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final space = snapshot.data!;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // Theme-reactive text color based on space background color
        final textColor = space.color.computeLuminance() > 0.5
            ? Colors.black87
            : Colors.white;

        // Subtle background opacity adjustment for theme
        final backgroundColor = isDark
            ? space.color.withValues(alpha: 0.8)
            : space.color.withValues(alpha: 0.9);

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: space.color.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Space icon (small)
              Icon(
                space.icon,
                size: fontSize + 1,
                color: textColor.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 4),
              // Space name
              Text(
                space.name,
                style: TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
