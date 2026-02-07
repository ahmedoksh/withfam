import 'dart:math' as math;

import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const double _previewHeight = 200;

/// Lightweight previews for history list.
class VisitMapPreview extends StatelessWidget {
  const VisitMapPreview({super.key, required this.point});

  final LatLng point;

  @override
  Widget build(BuildContext context) {
    final child = _supportsAppleMap
        ? _AppleVisitMap(point: point)
        : const _VisitPainterView();

    return Semantics(
      label:
          'Visit at ${point.latitude.toStringAsFixed(3)}, ${point.longitude.toStringAsFixed(3)}',
      child: child,
    );
  }
}

class TripMapPreview extends StatelessWidget {
  const TripMapPreview({
    super.key,
    required this.points,
    this.refreshNonce = 0,
  });

  final List<LatLng> points;
  final int refreshNonce;

  @override
  Widget build(BuildContext context) {
    if (_supportsAppleMap && points.isNotEmpty) {
      return _AppleTripMap(points: points, refreshNonce: refreshNonce);
    }

    return _TripPainterView(points: points);
  }
}

class _AppleVisitMap extends StatelessWidget {
  const _AppleVisitMap({required this.point});

  final LatLng point;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _previewHeight,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppleMap(
              key: ValueKey('visit-${point.latitude}-${point.longitude}'),
              initialCameraPosition: CameraPosition(target: point, zoom: 15),
              rotateGesturesEnabled: false,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              compassEnabled: false,
              myLocationEnabled: false,
              annotations: {
                Annotation(
                  annotationId: AnnotationId('visit'),
                  position: point,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AppleTripMap extends StatelessWidget {
  const _AppleTripMap({required this.points, required this.refreshNonce});

  final List<LatLng> points;
  final int refreshNonce;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasMultiple = points.length > 1;
        final bounds = hasMultiple ? _Bounds.from(points) : null;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final center = hasMultiple ? bounds!.center : points.first;
        final zoom = hasMultiple
            ? bounds!.estimatedZoom(widthPx: width, heightPx: _previewHeight)
            : 15.0;

        return SizedBox(
          height: _previewHeight,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppleMap(
                  key: ValueKey(
                    'trip-$refreshNonce-${points.length}-${points.first.latitude}-${points.first.longitude}',
                  ),
                  initialCameraPosition: CameraPosition(
                    target: center,
                    zoom: zoom,
                  ),
                  rotateGesturesEnabled: false,
                  scrollGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                  compassEnabled: false,
                  myLocationEnabled: false,
                  polylines: hasMultiple
                      ? {
                          Polyline(
                            polylineId: PolylineId(
                              'trip-${points.length}-${points.first.latitude}',
                            ),
                            points: points,
                            color: Colors.indigo,
                            width: 5,
                          ),
                        }
                      : const {},
                  annotations: {
                    Annotation(
                      annotationId: AnnotationId(
                        'start-${points.first.latitude}-${points.first.longitude}',
                      ),
                      position: points.first,
                    ),
                    if (hasMultiple)
                      Annotation(
                        annotationId: AnnotationId(
                          'end-${points.last.latitude}-${points.last.longitude}',
                        ),
                        position: points.last,
                      ),
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VisitPainterView extends StatelessWidget {
  const _VisitPainterView();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _previewHeight,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: _VisitPainter(),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _TripPainterView extends StatelessWidget {
  const _TripPainterView({required this.points});

  final List<LatLng> points;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _previewHeight,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: _TripPathPainter(points),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _VisitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final fill = Paint()..color = Colors.blueAccent.withOpacity(0.35);
    final outline = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, 32, fill);
    canvas.drawCircle(center, 32, outline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TripPathPainter extends CustomPainter {
  _TripPathPainter(this.points);

  final List<LatLng> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    if (points.length == 1) {
      final dot = Paint()..color = Colors.green;
      canvas.drawCircle(size.center(Offset.zero), 6, dot);
      return;
    }

    final minLat = points.map((p) => p.latitude).reduce(math.min);
    final maxLat = points.map((p) => p.latitude).reduce(math.max);
    final minLng = points.map((p) => p.longitude).reduce(math.min);
    final maxLng = points.map((p) => p.longitude).reduce(math.max);

    final latSpan = (maxLat - minLat).abs().clamp(0.0001, double.infinity);
    final lngSpan = (maxLng - minLng).abs().clamp(0.0001, double.infinity);

    const padding = 10.0;
    final scaleX = (size.width - 2 * padding) / lngSpan;
    final scaleY = (size.height - 2 * padding) / latSpan;
    final scale = math.min(scaleX, scaleY);

    Offset toOffset(LatLng p) {
      final x = padding + (p.longitude - minLng) * scale;
      final y = size.height - (padding + (p.latitude - minLat) * scale);
      return Offset(x, y);
    }

    final path = Path();
    final first = toOffset(points.first);
    path.moveTo(first.dx, first.dy);
    for (final p in points.skip(1)) {
      final o = toOffset(p);
      path.lineTo(o.dx, o.dy);
    }

    final pathPaint = Paint()
      ..color = Colors.indigo
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, pathPaint);

    final start = toOffset(points.first);
    final end = toOffset(points.last);
    canvas.drawCircle(start, 5, Paint()..color = Colors.green);
    canvas.drawCircle(end, 5, Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(covariant _TripPathPainter oldDelegate) =>
      oldDelegate.points != points;
}

bool get _supportsAppleMap => defaultTargetPlatform == TargetPlatform.iOS;

class _Bounds {
  _Bounds(this.minLat, this.maxLat, this.minLng, this.maxLng);

  factory _Bounds.from(List<LatLng> points) {
    final minLat = points.map((p) => p.latitude).reduce(math.min);
    final maxLat = points.map((p) => p.latitude).reduce(math.max);
    final minLng = points.map((p) => p.longitude).reduce(math.min);
    final maxLng = points.map((p) => p.longitude).reduce(math.max);
    return _Bounds(minLat, maxLat, minLng, maxLng);
  }

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  LatLng get center => LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

  double estimatedZoom({required double widthPx, required double heightPx}) {
    const tileSize = 256.0;
    const paddingFactor = 1.6; // zoom out slightly more for padding
    final latSpan = (maxLat - minLat).abs().clamp(0.0001, 180.0);
    final lngSpan = (maxLng - minLng).abs().clamp(0.0001, 360.0);

    double zoomForSpan(double span, double pixels) {
      final angle = span * paddingFactor;
      return math.log(360 * (pixels / tileSize) / angle) / math.ln2;
    }

    final zoomX = zoomForSpan(lngSpan, widthPx);
    final zoomY = zoomForSpan(latSpan, heightPx);
    return math.min(zoomX, zoomY).clamp(3.0, 18.0);
  }
}
