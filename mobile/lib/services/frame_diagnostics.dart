import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Bounded, on-demand debug telemetry. No document or account data is collected.
void installFrameDiagnostics({
  Map<String, Object> Function()? workspaceSummary,
}) {
  if (!kDebugMode) return;
  final frames = <FrameTiming>[];
  SchedulerBinding.instance.addTimingsCallback((batch) {
    frames.addAll(batch);
    if (frames.length > 600) frames.removeRange(0, frames.length - 600);
  });
  developer.registerExtension('ext.folio.frameTimings', (_, parameters) async {
    if (parameters['reset'] == 'true') frames.clear();
    Map<String, Object> summarize(Iterable<Duration> timings) {
      final values =
          timings.map((d) => d.inMicroseconds / 1000).toList()..sort();
      if (values.isEmpty) return {'p50Ms': 0, 'p95Ms': 0, 'maxMs': 0};
      return {
        'p50Ms': values[(values.length * .5).floor()],
        'p95Ms': values[((values.length - 1) * .95).ceil()],
        'maxMs': values.last,
      };
    }

    return developer.ServiceExtensionResponse.result(
      jsonEncode({
        'frames': frames.length,
        'build': summarize(frames.map((f) => f.buildDuration)),
        'raster': summarize(frames.map((f) => f.rasterDuration)),
        'over8ms':
            frames
                .where(
                  (f) =>
                      f.buildDuration.inMicroseconds > 8333 ||
                      f.rasterDuration.inMicroseconds > 8333,
                )
                .length,
        if (workspaceSummary != null) 'workspace': workspaceSummary(),
        'over16ms':
            frames
                .where(
                  (f) =>
                      f.buildDuration.inMicroseconds > 16667 ||
                      f.rasterDuration.inMicroseconds > 16667,
                )
                .length,
        'mode': 'debug; not a release benchmark',
      }),
    );
  });
}
