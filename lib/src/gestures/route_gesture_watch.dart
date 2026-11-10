import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/widgets.dart';

/// Notices a [Navigator] taking the finger for a route gesture.
///
/// A control that commits from raw pointer events never hears the gesture
/// arena. On Android that does not matter for the back gesture — it belongs to
/// the system, which cancels the pointer on its way out. The iOS edge swipe is
/// a drag recogniser in Flutter's own arena: no cancel is sent, the events keep
/// arriving, and the page slides *with* the finger, so on release the finger is
/// still over the control it went down on. Left alone, swiping back from over a
/// button pressed the button.
///
/// The navigator says when such a gesture is under way
/// ([NavigatorState.userGestureInProgressNotifier]); every navigator above the
/// control is watched while its finger is down, the same way the scrollables
/// above it are.
///
/// **The gesture being under way is not enough: the finger must have moved.**
/// With nothing else in the arena, the swipe recogniser is its only member and
/// wins the pointer by default the moment it goes down — a plain tap inside the
/// edge strip is a "route gesture in progress" from its first event to its
/// last. It has not moved the page, and the press is still the control's.
class RouteGestureWatch {
  RouteGestureWatch(this._onTakenOver);

  final VoidCallback _onTakenOver;

  final List<ValueNotifier<bool>> _navigators = <ValueNotifier<bool>>[];
  Offset _downAt = Offset.zero;
  Offset _last = Offset.zero;

  /// Starts watching for the finger that went down at [globalPosition].
  void watch(BuildContext context, Offset globalPosition) {
    unwatch();
    _downAt = globalPosition;
    _last = globalPosition;
    // Found without depending on them: this runs in an event handler.
    NavigatorState? navigator = context
        .findAncestorStateOfType<NavigatorState>();
    while (navigator != null) {
      final ValueNotifier<bool> inProgress =
          navigator.userGestureInProgressNotifier;
      _navigators.add(inProgress);
      inProgress.addListener(_check);
      navigator = navigator.context.findAncestorStateOfType<NavigatorState>();
    }
  }

  /// The watched finger moved to [globalPosition].
  void moved(Offset globalPosition) {
    if (_navigators.isEmpty) return;
    _last = globalPosition;
    _check();
  }

  void unwatch() {
    for (final ValueNotifier<bool> inProgress in _navigators) {
      inProgress.removeListener(_check);
    }
    _navigators.clear();
  }

  void _check() {
    if ((_last - _downAt).distance <= kTouchSlop) return;
    if (!_navigators.any((ValueNotifier<bool> n) => n.value)) return;
    unwatch();
    _onTakenOver();
  }
}
