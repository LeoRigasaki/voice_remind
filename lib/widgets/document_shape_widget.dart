import 'package:flutter/material.dart';

class DocumentShapeWidget extends StatelessWidget {
  final double width;
  final double height;
  final Color borderColor;
  final Color? fillColor;
  final double borderWidth;
  final bool showShadow;
  final double shadowBlur;
  final Color shadowColor;

  const DocumentShapeWidget({
    super.key,
    this.width = 150,
    this.height = 150,
    this.borderColor = Colors.black,
    this.fillColor = const Color(0xFFD9D9D9),
    this.borderWidth = 1.0,
    this.showShadow = true,
    this.shadowBlur = 4.0,
    this.shadowColor = Colors.black26,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width + (showShadow ? shadowBlur * 2 : 0),
      height: height + (showShadow ? shadowBlur * 2 : 0),
      child: CustomPaint(
        size: Size(width, height),
        painter: DocumentShapePainter(
          borderColor: borderColor,
          fillColor: fillColor,
          borderWidth: borderWidth,
          showShadow: showShadow,
          shadowBlur: shadowBlur,
          shadowColor: shadowColor,
        ),
      ),
    );
  }
}

class DocumentShapePainter extends CustomPainter {
  final Color borderColor;
  final Color? fillColor;
  final double borderWidth;
  final bool showShadow;
  final double shadowBlur;
  final Color shadowColor;

  DocumentShapePainter({
    required this.borderColor,
    this.fillColor,
    required this.borderWidth,
    required this.showShadow,
    required this.shadowBlur,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Scale the original SVG coordinates (213x213) to our size
    final double scaleX = size.width / 209.0; // SVG internal width is 209
    final double scaleY = size.height / 205.0; // SVG internal height is 205

    // Apply shadow offset

    // Create the exact path from the SVG
    final Path path = Path();

    // Make corner radius scale with size instead of fixed 11.0
    final double cornerRadius = (size.width * 0.05)
        .clamp(3.0, 15.0); // 5% of width, clamped between 3-15px

    // Calculate key points scaled to our size
    final double leftEdge = 4 * scaleX;
    final double rightEdge = 209 * scaleX;
    final double topEdge = 0 * scaleY;
    final double bottomEdge = 205 * scaleY;

    // Folded corner coordinates (scaled)
    final double foldStartX = 47.6712 * scaleX;
    final double foldStartY = 0 * scaleY;
    final double foldEndX = 39.5357 * scaleX;
    final double foldEndY = 3.17879 * scaleY;
    final double foldControlX = 7.8645 * scaleX;
    final double foldControlY = 32.388 * scaleY;
    final double foldTargetY = 41.2093 * scaleY;

    // Start the path from the folded corner area
    path.moveTo(foldStartX, foldStartY);

    // Top edge to top-right corner with SCALED radius
    path.lineTo(rightEdge - cornerRadius, topEdge);
    path.arcToPoint(
      Offset(rightEdge, topEdge + cornerRadius),
      radius: Radius.circular(cornerRadius),
    );

    // Right edge down to bottom-right corner
    path.lineTo(rightEdge, bottomEdge - cornerRadius);
    path.arcToPoint(
      Offset(rightEdge - cornerRadius, bottomEdge),
      radius: Radius.circular(cornerRadius),
    );

    // Bottom edge to bottom-left corner
    path.lineTo(leftEdge + cornerRadius, bottomEdge);
    path.arcToPoint(
      Offset(leftEdge, bottomEdge - cornerRadius),
      radius: Radius.circular(cornerRadius),
    );

    // Left edge up to the folded area
    path.lineTo(leftEdge, foldTargetY);

    // Curved fold section (this is the key part from the SVG)
    path.cubicTo(
      leftEdge, foldTargetY - 8 * scaleY, // Control point 1
      foldControlX, foldControlY, // Control point 2
      foldEndX, foldEndY, // End point
    );

    // Back to start
    path.lineTo(foldStartX, foldStartY);

    path.close();

    // Draw shadow if enabled
    if (showShadow) {
      final Paint shadowPaint = Paint()
        ..color = shadowColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur);

      canvas.save();
      canvas.translate(0, shadowBlur / 2);
      canvas.drawPath(path, shadowPaint);
      canvas.restore();
    }

    // Fill the shape if fillColor is provided
    if (fillColor != null) {
      final Paint fillPaint = Paint()
        ..color = fillColor!
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    }

    // Draw the border
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Three-Card Component for Reminder Categories
class ReminderCategoryCards extends StatelessWidget {
  final double baseWidth;
  final double baseHeight;
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final bool showShadow;
  final String primaryLabel;
  final String primaryCount;
  final String secondaryLabel1;
  final String secondaryCount1;
  final String secondaryLabel2;
  final String secondaryCount2;
  final double spacing;

  const ReminderCategoryCards({
    super.key,
    this.baseWidth = 100,
    this.baseHeight = 120,
    this.fillColor = Colors.black,
    this.borderColor = Colors.black,
    this.borderWidth = 2.0,
    this.showShadow = false,
    this.primaryLabel = 'Primary',
    this.primaryCount = '24',
    this.secondaryLabel1 = 'Work',
    this.secondaryCount1 = '8',
    this.secondaryLabel2 = 'Personal',
    this.secondaryCount2 = '12',
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Card A (Left - Primary card)
        Stack(
          alignment: Alignment.center,
          children: [
            DocumentShapeWidget(
              width: baseWidth * 0.8,
              height: baseHeight * 0.8,
              fillColor: fillColor,
              borderColor: borderColor,
              borderWidth: borderWidth,
              showShadow: showShadow,
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  primaryLabel,
                  style: TextStyle(
                    fontSize: (baseWidth * 0.14).clamp(10, 16),
                    fontWeight: FontWeight.bold,
                    color: fillColor == Colors.black ||
                            fillColor.computeLuminance() < 0.5
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
                Text(
                  primaryCount,
                  style: TextStyle(
                    fontSize: (baseWidth * 0.12).clamp(8, 14),
                    color: fillColor == Colors.black ||
                            fillColor.computeLuminance() < 0.5
                        ? Colors.white70
                        : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),

        SizedBox(width: spacing),

        // Cards B and C (Right - Secondary cards)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Card B (Top right)
            Stack(
              alignment: Alignment.center,
              children: [
                DocumentShapeWidget(
                  width: baseWidth * 0.6,
                  height: baseHeight * 0.35,
                  fillColor: fillColor,
                  borderColor: borderColor,
                  borderWidth: borderWidth,
                  showShadow: showShadow,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      secondaryLabel1,
                      style: TextStyle(
                        fontSize: (baseWidth * 0.12).clamp(8, 14),
                        fontWeight: FontWeight.bold,
                        color: fillColor == Colors.black ||
                                fillColor.computeLuminance() < 0.5
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    Text(
                      secondaryCount1,
                      style: TextStyle(
                        fontSize: (baseWidth * 0.1).clamp(6, 12),
                        color: fillColor == Colors.black ||
                                fillColor.computeLuminance() < 0.5
                            ? Colors.white70
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: spacing),

            // Card C (Bottom right)
            Stack(
              alignment: Alignment.center,
              children: [
                DocumentShapeWidget(
                  width: baseWidth * 0.6,
                  height: baseHeight * 0.35,
                  fillColor: fillColor,
                  borderColor: borderColor,
                  borderWidth: borderWidth,
                  showShadow: showShadow,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      secondaryLabel2,
                      style: TextStyle(
                        fontSize: (baseWidth * 0.12).clamp(8, 14),
                        fontWeight: FontWeight.bold,
                        color: fillColor == Colors.black ||
                                fillColor.computeLuminance() < 0.5
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    Text(
                      secondaryCount2,
                      style: TextStyle(
                        fontSize: (baseWidth * 0.1).clamp(6, 12),
                        color: fillColor == Colors.black ||
                                fillColor.computeLuminance() < 0.5
                            ? Colors.white70
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// Simplified version without shadow for better performance
class SimpleDocumentWidget extends StatelessWidget {
  final double width;
  final double height;
  final Color borderColor;
  final Color? fillColor;
  final double borderWidth;

  const SimpleDocumentWidget({
    super.key,
    this.width = 120,
    this.height = 120,
    this.borderColor = Colors.grey,
    this.fillColor,
    this.borderWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: SimpleDocumentPainter(
        borderColor: borderColor,
        fillColor: fillColor,
        borderWidth: borderWidth,
      ),
    );
  }
}

class SimpleDocumentPainter extends CustomPainter {
  final Color borderColor;
  final Color? fillColor;
  final double borderWidth;

  SimpleDocumentPainter({
    required this.borderColor,
    this.fillColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint fillPaint = Paint()
      ..color = fillColor ?? Colors.transparent
      ..style = PaintingStyle.fill;

    // Simplified version of the document shape
    final Path path = Path();

    final double foldSize = size.width * 0.25; // 25% for fold
    final double cornerRadius = size.width * 0.08; // 8% for corners

    // Start from fold point
    path.moveTo(foldSize, 0);

    // Top edge to top-right corner
    path.lineTo(size.width - cornerRadius, 0);
    path.arcToPoint(
      Offset(size.width, cornerRadius),
      radius: Radius.circular(cornerRadius),
    );

    // Right edge
    path.lineTo(size.width, size.height - cornerRadius);
    path.arcToPoint(
      Offset(size.width - cornerRadius, size.height),
      radius: Radius.circular(cornerRadius),
    );

    // Bottom edge
    path.lineTo(cornerRadius, size.height);
    path.arcToPoint(
      Offset(0, size.height - cornerRadius),
      radius: Radius.circular(cornerRadius),
    );

    // Left edge up to fold
    path.lineTo(0, foldSize);

    // Curved fold
    path.quadraticBezierTo(
      foldSize * 0.3,
      foldSize * 0.3,
      foldSize,
      0,
    );

    path.close();

    // Fill first, then border
    if (fillColor != null) {
      canvas.drawPath(path, fillPaint);
    }
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
