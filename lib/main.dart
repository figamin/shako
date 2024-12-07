import 'dart:math';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/material/colors.dart' as colors2;

void main() {
  runApp(const ShakoApp());
}

class ShakoApp extends StatelessWidget {
  const ShakoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const ShakoScreen(),
    );
  }
}

class ShakoScreen extends StatefulWidget {
  const ShakoScreen({Key? key}) : super(key: key);

  @override
  State<ShakoScreen> createState() => _ShakoScreenState();
}

class _ShakoScreenState extends State<ShakoScreen> {
  final TransformationController _transformController = TransformationController();
  double hashMarkOffset = 50;
  bool _isControlPressed = false;

  static const double _aspectRatio = 100 / 53.3; // Football field aspect ratio
  static const double _minScale = 0.25;
  static const double _maxScale = 4.0;

  @override
  void initState() {
    super.initState();
    RawKeyboard.instance.addListener(_handleKeyPress);
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_handleKeyPress);
    _transformController.dispose();
    super.dispose();
  }

  void _handleKeyPress(RawKeyEvent event) {
    setState(() {
      _isControlPressed = event.isControlPressed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Football Field'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: colors2.Colors.black,
                foregroundColor: colors2.Colors.white,
              ),
              onPressed: _resetView,
              child: const Text("Reset View"),
            ),
          ),
        ],
      ),
      body: Listener(
        onPointerSignal: (PointerSignalEvent event) {
          if (event is PointerScrollEvent) {
            if (_isControlPressed) {
              // Zoom when Control key is held
              _onScrollZoom(event.scrollDelta.dy);
            } else {
              // Pan when Control key is not held
              _onScrollPan(event.scrollDelta);
            }
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final marginHorizontal = 32.0; // Left and right margins
            final marginVertical = 16.0; // Top and bottom margins

            final availableWidth = constraints.maxWidth - 2 * marginHorizontal;
            final availableHeight = constraints.maxHeight - 2 * marginVertical;

            // Calculate dimensions while maintaining aspect ratio
            double width, height;
            if (availableWidth / availableHeight > _aspectRatio) {
              // Window is wider than the aspect ratio suggests
              height = availableHeight;
              width = height * _aspectRatio;
            } else {
              // Window is taller than the aspect ratio suggests
              width = availableWidth;
              height = width / _aspectRatio;
            }

            final minScale = min(
              availableWidth / width,
              availableHeight / height,
            );

            return Center(
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: marginHorizontal,
                  vertical: marginVertical,
                ),
                child: InteractiveViewer(
                  transformationController: _transformController,
                  maxScale: _maxScale,
                  minScale: minScale,
                  panEnabled: true,
                  scaleEnabled: _isControlPressed, // Only scale when Control is pressed
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: CustomPaint(
                      size: Size(width, height),
                      painter: ShakoPainter(
                        hashMarkOffset: hashMarkOffset,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _onScrollZoom(double delta) {
    final Matrix4 currentMatrix = _transformController.value;
    final double currentScale = currentMatrix.getMaxScaleOnAxis();
    
    // Calculate new scale
    final double zoomChange = delta < 0 ? 0.25 : -0.25;
    final double newScale = (currentScale + zoomChange).clamp(_minScale, _maxScale);
    
    // Calculate the scaling factor
    final double scaleFactor = newScale / currentScale;
    
    // Create a new transformation matrix
    final Matrix4 zoomedMatrix = Matrix4.identity()
      ..scale(scaleFactor, scaleFactor)
      ..multiply(currentMatrix);
    
    _transformController.value = zoomedMatrix;
  }

  void _onScrollPan(Offset scrollDelta) {
    if (!_isControlPressed) {
      final Matrix4 currentMatrix = _transformController.value;
      final double currentScale = currentMatrix.getMaxScaleOnAxis();
      
      // Adjust pan speed based on current scale
      final Offset adjustedDelta = Offset(
        scrollDelta.dx / currentScale, 
        scrollDelta.dy / currentScale
      );
      
      // Create a new matrix with updated translation
      final Matrix4 panMatrix = Matrix4.translationValues(
        -adjustedDelta.dx, 
        -adjustedDelta.dy, 
        0
      );
      
      // Multiply the current matrix with the pan matrix to preserve existing transformations
      final Matrix4 updatedMatrix = panMatrix.multiplied(currentMatrix);
      
      _transformController.value = updatedMatrix;
    }
  }

  void _resetView() {
    _transformController.value = Matrix4.identity();
  }
}
// The ShakoPainter remains unchanged from the original implementation
class ShakoPainter extends CustomPainter {
  final double hashMarkOffset;

  ShakoPainter({required this.hashMarkOffset});

  @override
  void paint(Canvas canvas, Size size) {
    // Paints for various components
    final boundaryPaint = Paint()
      ..color = colors2.Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final lightGrayLinePaint = Paint()
      ..color = colors2.Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final darkGrayLinePaint = Paint()
      ..color = colors2.Colors.grey[700]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final blackLinePaint = Paint()
      ..color = colors2.Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final textStyle = const TextStyle(color: colors2.Colors.black, fontSize: 36);

    // Draw field boundary
    final fieldRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(fieldRect, boundaryPaint);

    // 1. Draw light gray vertical lines
    final linesPer5Yards = 8;
    final totalLines = linesPer5Yards * 20; // 20 segments in 100 yards
    final lineSpacing = size.width / totalLines;

    List<double> verticalLinePositions = [];

    for (int i = 0; i <= totalLines; i++) {
      final x = i * lineSpacing;
      final isMajorLine = i % linesPer5Yards == 0;
      final isMiddleLine = i % linesPer5Yards == 4;

      // Draw the light gray vertical lines
      if (!(isMajorLine || isMiddleLine)) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          lightGrayLinePaint,
        );
      }

      // Record positions of the vertical lines (for hash marks)
      if (isMajorLine || isMiddleLine) {
        verticalLinePositions.add(x);
      }
    }

    // 2. Draw light gray horizontal lines
    final linesPer5YardsHorizontal = 8;
    final totalHorizontalLines = linesPer5YardsHorizontal *
        20; // 20 segments in 50 yards (for top and bottom)
    final lineSpacingHeight = size.height / totalHorizontalLines;

    for (int i = 0; i <= totalHorizontalLines; i++) {
      final y = i * lineSpacingHeight;
      // Draw the light gray horizontal lines
      if (i % linesPer5YardsHorizontal != 0 && i % 2 == 0) {
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          lightGrayLinePaint,
        );
      }
    }

    // 3. Draw dark gray vertical lines
    for (int i = 0; i <= totalLines; i++) {
      final x = i * lineSpacing;
      final isMajorLine = i % linesPer5Yards == 0;
      final isMiddleLine = i % linesPer5Yards == 4;

      if (isMiddleLine) {
        // Draw the dark gray vertical lines
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          darkGrayLinePaint,
        );
      }
    }

    // 4. Draw black vertical lines (major lines)
    for (int i = 0; i <= totalLines; i++) {
      final x = i * lineSpacing;
      final isMajorLine = i % linesPer5Yards == 0;
      if (isMajorLine) {
        // Draw the black vertical lines (major lines)
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          blackLinePaint,
        );
      }
    }

    // 5. Draw black horizontal lines (major lines)
    for (int i = 0; i <= totalHorizontalLines; i++) {
      final y = i * lineSpacingHeight;
      final isMajorLine = i % linesPer5YardsHorizontal == 0;
      if (isMajorLine) {
        // Draw the black horizontal lines (major lines)
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          darkGrayLinePaint,
        );
      }
    }

    final hashMarkLength = size.width / 75;

    for (int i = 0; i <= totalLines; i++) {
      final x = i * lineSpacing;
      final isMajorLine = i % linesPer5Yards == 0;
      final isMiddleLine = i % linesPer5Yards == 4;

      // Draw hash marks for major and middle lines only
      if (isMajorLine || isMiddleLine) {
        // Top hash marks
        canvas.drawLine(
          Offset(x - 10,
              size.height * (hashMarkOffset / 53.3)), // Scaled to height
          Offset(
              x - 10 + hashMarkLength, size.height * (hashMarkOffset / 53.3)),
          blackLinePaint,
        );

        // Bottom hash marks
        canvas.drawLine(
          Offset(x - 10,
              size.height * (1 - (hashMarkOffset / 53.3))), // Scaled to height
          Offset(x - 10 + hashMarkLength,
              size.height * (1 - (hashMarkOffset / 53.3))),
          blackLinePaint,
        );
      }
    }

    // 7. Draw yard numbers (on top of everything else)
    final numberTextStyle = textStyle.copyWith(fontWeight: FontWeight.bold);
    for (int i = 0; i <= totalLines; i++) {
      final x = i * lineSpacing;
      final isMajorLine = i % linesPer5Yards == 0;
      if (isMajorLine &&
          i % (2 * linesPer5Yards) == 0 &&
          i != 0 &&
          i != totalLines) {
        final yardNumber = (i ~/ linesPer5Yards) * 5;
        final numberText = (yardNumber <= 50)
            ? yardNumber.toString()
            : (100 - yardNumber).toString();

        final textSpan = TextSpan(text: numberText, style: numberTextStyle);
        final textPainter =
            TextPainter(text: textSpan, textDirection: TextDirection.ltr);
        textPainter.layout();

        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2,
              size.height / 2 - textPainter.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
