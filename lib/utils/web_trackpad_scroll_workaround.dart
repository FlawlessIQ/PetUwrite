import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Debug-only workaround for a Flutter Web assertion on macOS trackpads.
///
/// In some Flutter versions, web wheel events can be converted into pointer
/// packets where `kind == trackpad` and `signalKind == scroll`, which then hits
/// a framework assert when constructing `PointerScrollEvent`.
///
/// This normalizes such packets by coercing the kind to `mouse` for scroll
/// signals only.
void installWebTrackpadScrollWorkaroundIfNeeded() {
  if (!kIsWeb) return;

  assert(() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final original = dispatcher.onPointerDataPacket;

    dispatcher.onPointerDataPacket = (ui.PointerDataPacket packet) {
      // Fast-path: only allocate when we actually see trackpad+scroll.
      var needsFix = false;
      for (final data in packet.data) {
        if (data.kind == ui.PointerDeviceKind.trackpad &&
            data.signalKind == ui.PointerSignalKind.scroll) {
          needsFix = true;
          break;
        }
      }

      if (!needsFix) {
        original?.call(packet);
        return;
      }

      final fixed = ui.PointerDataPacket(
        data: packet.data
            .map(
              (data) => _coerceTrackpadScrollKindToMouse(data),
            )
            .toList(growable: false),
      );

      original?.call(fixed);
    };

    debugPrint('Installed web trackpad scroll workaround (debug-only).');
    return true;
  }());
}

ui.PointerData _coerceTrackpadScrollKindToMouse(ui.PointerData data) {
  if (data.kind != ui.PointerDeviceKind.trackpad ||
      data.signalKind != ui.PointerSignalKind.scroll) {
    return data;
  }

  return ui.PointerData(
    viewId: data.viewId,
    embedderId: data.embedderId,
    timeStamp: data.timeStamp,
    change: data.change,
    kind: ui.PointerDeviceKind.mouse,
    signalKind: data.signalKind,
    device: data.device,
    pointerIdentifier: data.pointerIdentifier,
    physicalX: data.physicalX,
    physicalY: data.physicalY,
    physicalDeltaX: data.physicalDeltaX,
    physicalDeltaY: data.physicalDeltaY,
    buttons: data.buttons,
    obscured: data.obscured,
    synthesized: data.synthesized,
    pressure: data.pressure,
    pressureMin: data.pressureMin,
    pressureMax: data.pressureMax,
    distance: data.distance,
    distanceMax: data.distanceMax,
    size: data.size,
    radiusMajor: data.radiusMajor,
    radiusMinor: data.radiusMinor,
    radiusMin: data.radiusMin,
    radiusMax: data.radiusMax,
    orientation: data.orientation,
    tilt: data.tilt,
    platformData: data.platformData,
    scrollDeltaX: data.scrollDeltaX,
    scrollDeltaY: data.scrollDeltaY,
    panX: data.panX,
    panY: data.panY,
    panDeltaX: data.panDeltaX,
    panDeltaY: data.panDeltaY,
    scale: data.scale,
    rotation: data.rotation,
    onRespond: ({bool allowPlatformDefault = true}) {
      data.respond(allowPlatformDefault: allowPlatformDefault);
    },
  );
}
