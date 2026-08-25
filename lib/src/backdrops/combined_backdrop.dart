import 'package:flutter/foundation.dart';

import '../backdrop.dart';

/// Draws several backdrops on top of one another, in order.
class CombinedBackdrop extends Backdrop {
  CombinedBackdrop(this.backdrops)
      : isCoordinatesDependent =
            backdrops.any((Backdrop backdrop) => backdrop.isCoordinatesDependent);

  CombinedBackdrop.of(Backdrop first, Backdrop second, [Backdrop? third, Backdrop? fourth])
      : this(<Backdrop>[
          first,
          second,
          ?third,
          ?fourth,
        ]);

  final List<Backdrop> backdrops;

  @override
  final bool isCoordinatesDependent;

  @override
  Listenable? get repaintNotifier {
    final List<Listenable> listenables = <Listenable>[
      for (final Backdrop backdrop in backdrops)
        if (backdrop.repaintNotifier != null) backdrop.repaintNotifier!,
    ];
    if (listenables.isEmpty) return null;
    if (listenables.length == 1) return listenables.first;
    return Listenable.merge(listenables);
  }

  @override
  void drawBackdrop(BackdropDrawContext context) {
    for (final Backdrop backdrop in backdrops) {
      backdrop.drawBackdrop(context);
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is! CombinedBackdrop) return false;
    if (other.backdrops.length != backdrops.length) return false;
    for (int i = 0; i < backdrops.length; i++) {
      if (other.backdrops[i] != backdrops[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(backdrops);
}
