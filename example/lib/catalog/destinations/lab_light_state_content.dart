import 'dart:async';
import 'dart:math' as math;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../lab/rim_light.dart';

/// Light as state: the rim of the glass says what the element is doing, in
/// place of a spinner, a toast or a red label.
///
/// * Tap a field — the light runs out of the finger round the field and stays.
/// * **Load** — a comet orbits the card.
/// * **Succeed** — the light leaves from wherever it is, sweeps both ways and
///   flares once where the two fronts meet.
/// * **Fail** — two warm pulses and a small shake.
/// * **Download** — the outline itself is the progress bar.
class LabLightStateContent extends StatefulWidget {
  const LabLightStateContent({super.key});

  @override
  State<LabLightStateContent> createState() => _LabLightStateContentState();
}

class _LabLightStateContentState extends State<LabLightStateContent>
    with TickerProviderStateMixin {
  final LayerBackdrop _backdrop = LayerBackdrop();

  late final RimLightController _card = RimLightController(vsync: this);
  late final List<RimLightController> _fields = <RimLightController>[
    RimLightController(vsync: this),
    RimLightController(vsync: this),
  ];
  late final RimLightController _download = RimLightController(vsync: this);

  int? _focused;
  Timer? _downloadTimer;
  double _downloaded = 0;
  bool _downloadDone = false;
  final math.Random _random = math.Random(7);

  static const RoundedRectangularShape _cardShape = RoundedRectangle(32);
  static const RoundedRectangularShape _fieldShape = RoundedRectangle(16);
  static const RoundedRectangularShape _pill = Capsule();

  @override
  void dispose() {
    _downloadTimer?.cancel();
    _card.dispose();
    for (final RimLightController f in _fields) {
      f.dispose();
    }
    _download.dispose();
    _backdrop.dispose();
    super.dispose();
  }

  void _focusField(int index, Offset at) {
    if (_focused == index) return;
    if (_focused != null) _fields[_focused!].clear();
    setState(() => _focused = index);
    _fields[index].focus(from: at);
  }

  void _unfocus() {
    if (_focused == null) return;
    _fields[_focused!].clear();
    setState(() => _focused = null);
  }

  void _startDownload() {
    if (_downloadTimer != null) return;
    if (_downloadDone) {
      setState(() {
        _downloadDone = false;
        _downloaded = 0;
      });
      _download.clear();
      return;
    }
    // An uneven rate, as a real download is: the light should look like it
    // is reporting something, not playing an animation.
    _downloadTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final double burst = _random.nextDouble() < 0.08 ? 0.0 : 1.0;
      _downloaded = math.min(
        1.0,
        _downloaded + burst * (0.004 + _random.nextDouble() * 0.006),
      );
      _download.setProgress(_downloaded);
      setState(() {});
      if (_downloaded >= 1.0) {
        _downloadTimer?.cancel();
        _downloadTimer = null;
        _downloadDone = true;
        _download.succeed();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color content = Color(0xFFFFFFFF);
    final Color surface = const Color(0xFF0E1620).withValues(alpha: 0.38);

    final Widget card = RimLight(
      controller: _card,
      shape: _cardShape,
      child: SizedBox(
        width: 320,
        child: LiquidPanel(
          backdrop: _backdrop,
          shape: _cardShape,
          surfaceColor: surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Sign in',
                  style: TextStyle(
                    color: content,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap a field, then try the buttons below.',
                  style: TextStyle(
                    color: content.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                _field(0, 'Email', Icons.alternate_email),
                const SizedBox(height: 10),
                _field(1, 'Password', Icons.lock_outline),
              ],
            ),
          ),
        ),
      ),
    );

    final Widget actions = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: <Widget>[
        _action('Load', () {
          _unfocus();
          _card.load();
        }),
        _action('Succeed', () {
          _unfocus();
          _card.succeed();
        }),
        _action('Fail', () {
          _unfocus();
          _card.fail();
        }),
      ],
    );

    final String label = _downloadDone
        ? 'Done — again?'
        : _downloadTimer != null
        ? '${(_downloaded * 100).round()}%'
        : 'Download';

    final Widget download = RimLight(
      controller: _download,
      shape: _pill,
      child: SizedBox(
        width: 280,
        height: 56,
        child: LiquidButton(
          backdrop: _backdrop,
          onPressed: _startDownload,
          height: 56,
          surfaceColor: surface,
          children: <Widget>[
            Icon(
              _downloadDone ? Icons.check_rounded : Icons.download_rounded,
              color: content,
              size: 20,
            ),
            Text(
              label,
              style: const TextStyle(
                color: content,
                fontSize: 16,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );

    return LiquidGlassTheme(
      colors: LiquidGlassColors.forBrightness(Brightness.dark),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _unfocus,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: <Widget>[
            Positioned.fill(
              child: BackdropLayer(
                backdrop: _backdrop,
                child: const LabWallpaper(),
              ),
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 22,
                  children: <Widget>[
                    card,
                    actions,
                    const SizedBox(height: 8),
                    download,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(int index, String hint, IconData icon) {
    const Color content = Color(0xFFFFFFFF);
    final bool focused = _focused == index;
    return RimLight(
      controller: _fields[index],
      shape: _fieldShape,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (TapDownDetails d) => _focusField(index, d.localPosition),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          // The field is opaque-ish on purpose: the glass is the card around
          // it, and a caret needs a background that does not move.
          decoration: ShapeDecoration(
            color: const Color(0xFF000000).withValues(alpha: 0.28),
            shape: const GlassShapeBorder(_fieldShape),
          ),
          child: Row(
            spacing: 10,
            children: <Widget>[
              Icon(icon, color: content.withValues(alpha: 0.7), size: 18),
              Text(
                focused ? '|' : hint,
                style: TextStyle(
                  color: content.withValues(alpha: focused ? 0.95 : 0.5),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(String label, VoidCallback onPressed) {
    return LiquidButton(
      backdrop: _backdrop,
      onPressed: onPressed,
      surfaceColor: const Color(0xFF0E1620).withValues(alpha: 0.38),
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 15),
        ),
      ],
    );
  }
}
