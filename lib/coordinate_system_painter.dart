import 'dart:ui';

import 'package:flutter/material.dart';

import 'model/coordinates_options.dart';
import 'theme/slidable_line_chart_theme.dart';

typedef OnDrawIndicator = bool Function(double value);

typedef GetXAxisTickLineWidth = double Function(double chartActualWidth);

typedef GetYAxisTickLineHeight = double Function(double chartActualHeight);

class CoordinateSystemPainter<Enum> extends CustomPainter {
  CoordinateSystemPainter({
    required this.slidableCoordinatesAnimationController,
    required this.otherCoordinatesAnimationController,
    required this.slidableCoordinateType,
    required this.coordinatesMap,
    required this.xAxis,
    required this.yAxis,
    required this.min,
    required this.max,
    required this.maxOffsetValueOnYAxisSlidingArea,
    required this.coordinateSystemOrigin,
    required this.divisions,
    required this.reversed,
    required this.onlyRenderEvenAxisLabel,
    required this.slidableLineChartThemeData,
    required this.onDrawCheckOrClose,
    required this.getXAxisTickLineWidth,
    required this.getYAxisTickLineHeight,
  }) : super(
          repaint: Listenable.merge(
            <AnimationController?>[
              slidableCoordinatesAnimationController,
              otherCoordinatesAnimationController,
            ],
          ),
        );

  final AnimationController? slidableCoordinatesAnimationController;

  final AnimationController? otherCoordinatesAnimationController;

  final Enum? slidableCoordinateType;

  final Map<Enum, Coordinates<Enum>> coordinatesMap;

  final List<String> xAxis;

  final List<int> yAxis;

  final int min;

  final int max;

  final double maxOffsetValueOnYAxisSlidingArea;

  final Offset coordinateSystemOrigin;

  final int divisions;

  final bool reversed;

  final bool onlyRenderEvenAxisLabel;

  final SlidableLineChartThemeData<Enum>? slidableLineChartThemeData;

  final OnDrawIndicator? onDrawCheckOrClose;

  final GetXAxisTickLineWidth getXAxisTickLineWidth;

  final GetYAxisTickLineHeight getYAxisTickLineHeight;

  Color get defaultCoordinatePointColor =>
      slidableLineChartThemeData?.defaultCoordinatePointColor ??
      kDefaultCoordinatePointColor;
  Color get defaultLineColor =>
      slidableLineChartThemeData?.defaultLineColor ?? kDefaultLineColor;
  Color get defaultFillAreaColor =>
      slidableLineChartThemeData?.defaultFillAreaColor ??
      slidableLineChartThemeData?.defaultCoordinatePointColor ??
      kDefaultFillAreaColor;

  final TextPainter _textPainter =
      TextPainter(textDirection: TextDirection.ltr);

  late final Paint axisLinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = slidableLineChartThemeData?.axisLineColor ?? kAxisLineColor
    ..strokeWidth = slidableLineChartThemeData?.axisLineWidth ?? kAxisLineWidth;

  late final Paint gridLinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = slidableLineChartThemeData?.gridLineColor ?? kGridLineColor
    ..strokeWidth = slidableLineChartThemeData?.gridLineWidth ?? kGridLineWidth;

  final Paint coordinatePointPaint = Paint();

  late final Paint linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = slidableLineChartThemeData?.lineWidth ?? kLineWidth;

  final Paint fillAreaPaint = Paint();

  final Paint tapAreaPaint = Paint();

  late double _chartWidth;
  late double _chartHeight;

  late double _chartActualWidth;
  late double _chartActualHeight;

  @override
  void paint(Canvas canvas, Size size) {
    _chartWidth = size.width;
    _chartHeight = size.height;

    _chartActualWidth = _chartWidth - coordinateSystemOrigin.dx;
    _chartActualHeight = _chartHeight - coordinateSystemOrigin.dy;

    final Path axisLinePath = Path()
      // X-Axis
      ..moveTo(0.0, _chartActualHeight)
      ..relativeLineTo(_chartWidth, 0.0)
      // Y-Axis
      ..moveTo(coordinateSystemOrigin.dx, 0.0)
      ..relativeLineTo(0.0, _chartHeight);
    canvas.drawPath(axisLinePath, axisLinePaint);

    final double xAxisTickLineWidth = getXAxisTickLineWidth(_chartActualWidth);

    drawXAxis(canvas, xAxisTickLineWidth: xAxisTickLineWidth);
    drawYAxis(canvas);

    drawCoordinates(canvas, xAxisTickLineWidth: xAxisTickLineWidth);
  }

  void drawCoordinates(
    Canvas canvas, {
    required double xAxisTickLineWidth,
  }) {
    final Map<Enum, CoordinatesStyle<Enum>>? coordinatesStyleMap =
        slidableLineChartThemeData?.coordinatesStyleMap;

    // Draw other coordinates first so that the slidable coordinates are drawn at
    // the top level.
    for (final Coordinates<Enum> coordinates in coordinatesMap.values) {
      if (coordinates.type == slidableCoordinateType) {
        continue; // Skip slidable coordinates.
      }

      final CoordinatesStyle<Enum>? coordinatesStyle =
          coordinatesStyleMap?[coordinates.type];

      drawLineAndFillArea(
        canvas,
        animationController: otherCoordinatesAnimationController,
        coordinates: coordinates,
        lineColor: coordinatesStyle?.lineColor,
        fillAreaColor: coordinatesStyle?.fillAreaColor,
      );

      for (final Coordinate coordinate in coordinates.value) {
        coordinate.drawCoordinatePoint(
          canvas,
          coordinatePointPaint
            ..color =
                coordinatesStyle?.pointColor ?? defaultCoordinatePointColor,
        );
      }
    }

    final Coordinates<Enum>? slidableCoordinates =
        coordinatesMap[slidableCoordinateType];

    if (slidableCoordinates != null) {
      final CoordinatesStyle<Enum>? slidableCoordinatesStyle =
          coordinatesStyleMap?[slidableCoordinates.type];

      drawLineAndFillArea(
        canvas,
        animationController: slidableCoordinatesAnimationController,
        coordinates: slidableCoordinates,
        lineColor: slidableCoordinatesStyle?.lineColor,
        fillAreaColor: slidableCoordinatesStyle?.fillAreaColor,
      );

      for (final Coordinate coordinate in slidableCoordinates.value) {
        if (slidableLineChartThemeData?.showTapArea ?? kShowTapArea) {
          coordinate.drawTapArea(
            canvas,
            tapAreaPaint
              ..color = slidableCoordinatesStyle?.tapAreaColor ??
                  slidableCoordinatesStyle?.pointColor?.withOpacity(.2) ??
                  slidableLineChartThemeData?.defaultTapAreaColor ??
                  kTapAreaColor,
          );
        }

        coordinate.drawCoordinatePoint(
          canvas,
          coordinatePointPaint
            ..color = slidableCoordinatesStyle?.pointColor ??
                defaultCoordinatePointColor,
        );

        _drawDisplayValueText(
          canvas,
          dx: coordinate.offset.dx,
          displayValue: coordinate.value,
        );

        final bool? result = onDrawCheckOrClose?.call(coordinate.value);

        final double radius =
            slidableLineChartThemeData?.indicatorRadius ?? kIndicatorRadius;

        final double y = (slidableLineChartThemeData?.indicatorMarginTop ??
                kIndicatorMarginTop) +
            _chartHeight;

        switch (result) {
          case null:
            break;
          case true:
            _drawCheck(canvas, radius: radius, x: coordinate.offset.dx, y: y);
            break;
          case false:
            _drawClose(canvas, radius: radius, x: coordinate.offset.dx, y: y);
            break;
        }
      }
    }
  }

  void drawLineAndFillArea(
    Canvas canvas, {
    required AnimationController? animationController,
    required Coordinates<Enum> coordinates,
    Color? lineColor,
    Color? fillAreaColor,
  }) {
    final Offset firstCoordinateOffset = coordinates.value.first.offset;

    final Color finalFillAreaColor = fillAreaColor ?? defaultFillAreaColor;

    final Path linePath = coordinates.value.skip(1).fold<Path>(
          Path()..moveTo(firstCoordinateOffset.dx, firstCoordinateOffset.dy),
          (Path path, Coordinate coordinate) =>
              path..lineTo(coordinate.offset.dx, coordinate.offset.dy),
        );

    final PathMetrics pathMetrics = linePath.computeMetrics();

    for (final PathMetric pathMetric in pathMetrics) {
      final double progress =
          pathMetric.length * (animationController?.value ?? 1);

      final Path path = pathMetric.extractPath(0.0, progress);

      canvas.drawPath(
        path,
        linePaint..color = lineColor ?? defaultLineColor,
      );

      final Tangent? tangent = pathMetric.getTangentForOffset(progress);

      final Path fillAreaPath = Path()
        ..moveTo(firstCoordinateOffset.dx, _chartActualHeight)
        ..addPath(path, Offset.zero)
        ..lineTo(tangent?.position.dx ?? 0.0, _chartActualHeight)
        ..lineTo(firstCoordinateOffset.dx, _chartActualHeight)
        ..close();

      canvas.drawPath(
        fillAreaPath,
        fillAreaPaint
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[
              finalFillAreaColor.withOpacity(0.2),
              finalFillAreaColor,
            ],
          ).createShader(
            Rect.fromLTWH(
              firstCoordinateOffset.dx,
              _chartActualHeight - maxOffsetValueOnYAxisSlidingArea,
              coordinates.value.last.offset.dx - firstCoordinateOffset.dx,
              maxOffsetValueOnYAxisSlidingArea,
            ),
          ),
      );
    }
  }

  void drawXAxis(
    Canvas canvas, {
    required double xAxisTickLineWidth,
  }) {
    canvas.save();

    canvas.translate(
      xAxisTickLineWidth / 2 + coordinateSystemOrigin.dx,
      _chartHeight,
    );

    for (int i = 0; i < xAxis.length; i++) {
      _drawAxisLabel(
        canvas,
        xAxis[i],
        drawXAxis: true,
        alignment: Alignment.center,
      );

      canvas.translate(xAxisTickLineWidth, 0);
    }

    canvas.restore();
  }

  void drawYAxis(Canvas canvas) {
    canvas.save();

    final double yAxisTickLineHeight =
        getYAxisTickLineHeight(_chartActualHeight);

    canvas.translate(
      coordinateSystemOrigin.dx,
      _chartActualHeight,
    );

    // The first line has an axis, so only text is drawn.
    _drawAxisLabel(
      canvas,
      yAxis[0].toString(),
    );

    canvas.translate(0.0, -yAxisTickLineHeight);

    for (int i = 1; i < yAxis.length; i++) {
      // Drawing coordinate line.
      canvas.drawLine(
        Offset.zero,
        Offset(_chartActualWidth, 0),
        gridLinePaint,
      );

      if (!onlyRenderEvenAxisLabel || (onlyRenderEvenAxisLabel && i.isEven)) {
        _drawAxisLabel(
          canvas,
          yAxis[i].toString(),
        );
      }

      canvas.translate(0.0, -yAxisTickLineHeight);
    }
    canvas.restore();
  }

  void _drawAxisLabel(
    Canvas canvas,
    String text, {
    bool drawXAxis = false,
    Alignment alignment = Alignment.centerLeft,
  }) {
    final TextSpan textSpan = TextSpan(
      text: text,
      style: slidableLineChartThemeData?.axisLabelStyle ?? kAxisLabelStyle,
    );

    _textPainter.text = textSpan;
    _textPainter.layout();

    final Size size = _textPainter.size;

    late double dx;
    late double dy;

    if (drawXAxis) {
      dx = 0.0;
      dy = size.height / 2;
    } else {
      dx = size.width + coordinateSystemOrigin.dx;
      dy = 0.0;
    }

    final Offset offset = Offset(-size.width / 2, -size.height / 2).translate(
      -size.width / 2 * alignment.x - dx,
      dy,
    );
    _textPainter.paint(canvas, offset);
  }

  void _drawDisplayValueText(
    Canvas canvas, {
    required double dx,
    required double displayValue,
  }) {
    final TextSpan textSpan = TextSpan(
      text: displayValue.toString(),
      style: slidableLineChartThemeData?.displayValueTextStyle ??
          kDisplayValueTextStyle,
    );

    _textPainter.text = textSpan;
    _textPainter.layout();

    final Size size = _textPainter.size;

    final Offset offset = Offset(-size.width / 2, -size.height).translate(
      dx,
      -(slidableLineChartThemeData?.displayValueMarginBottom ??
          kDisplayValueMarginBottom), // Makes the display value top.
    );
    _textPainter.paint(canvas, offset);
  }

  void _drawCheck(
    Canvas canvas, {
    required double radius,
    required double x,
    required double y,
  }) {
    final Path checkPath = Path()
      ..addPolygon(
        <Offset>[
          Offset(x - radius, y),
          Offset(x - radius / 3, y + (radius - radius / 3)),
          Offset(x + radius, y - radius * 2 / 3)
        ],
        false,
      );

    final Paint paint = Paint()
      ..color = slidableLineChartThemeData?.checkBackgroundColor ??
          kCheckBackgroundColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x, y), radius * 2, paint);

    canvas.drawPath(
      checkPath,
      paint
        ..color = slidableLineChartThemeData?.checkColor ?? kCheckColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.4,
    );
  }

  void _drawClose(
    Canvas canvas, {
    required double radius,
    required double x,
    required double y,
  }) {
    final double size = radius * 0.8;

    Paint paint = Paint()
      ..color = slidableLineChartThemeData?.closeBackgroundColor ??
          kCloseBackgroundColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x, y), radius * 2, paint);

    paint = paint
      ..color = slidableLineChartThemeData?.closeColor ?? kCloseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.4;

    canvas.drawLine(
      Offset(x - size, y - size),
      Offset(x + size, y + size),
      paint,
    );

    canvas.drawLine(
      Offset(x + size, y - size),
      Offset(x - size, y + size),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CoordinateSystemPainter<Enum> oldDelegate) =>
      true;
}
