// Probe: ProgressiveBlur over scrolling text, with the band mask and a raster
// timing readout.
//
//   flutter run -t lib/probe_progressive_blur.dart -d <device>
//
// Tap the top-left chip to cycle bands (0 = off, then 1, 3, 5, 8), the second
// chip to toggle the band mask, the third to auto-scroll. Raster averages are
// printed to the console every 60 frames, tagged PROBE.

import 'dart:async';

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() => runApp(const _ProbeApp());

class _ProbeApp extends StatefulWidget {
  const _ProbeApp();

  @override
  State<_ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<_ProbeApp> {
  static const List<int> _bandSteps = <int>[0, 1, 3, 5, 8];
  int _bandIndex = 3;
  bool _mask = false;
  bool _autoScroll = false;
  final ScrollController _scroll = ScrollController();
  Timer? _scrollTimer;
  final List<double> _raster = <double>[];

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final FrameTiming t in timings) {
      _raster.add(t.rasterDuration.inMicroseconds / 1000);
    }
    if (_raster.length >= 60) {
      final double avg = _raster.reduce((a, b) => a + b) / _raster.length;
      final List<double> sorted = List<double>.of(_raster)..sort();
      final double p90 = sorted[(sorted.length * 0.9).floor()];
      debugPrint(
        'PROBE bands=${_bandSteps[_bandIndex]} mask=$_mask '
        'raster avg=${avg.toStringAsFixed(2)}ms p90=${p90.toStringAsFixed(2)}ms',
      );
      _raster.clear();
    }
  }

  void _toggleAutoScroll() {
    _autoScroll = !_autoScroll;
    _scrollTimer?.cancel();
    if (_autoScroll) {
      _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (!_scroll.hasClients) return;
        final double next = _scroll.offset + 3;
        _scroll.jumpTo(next > _scroll.position.maxScrollExtent ? 0 : next);
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int bands = _bandSteps[_bandIndex];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF12110F),
        body: Stack(
          children: <Widget>[
            ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 160, 16, 400),
              itemCount: 200,
              itemBuilder: (BuildContext context, int i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: i.isEven
                        ? const Color(0xFF2A2825)
                        : const Color(0xFFE77A52),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '第 $i 行 · 现在是周一的下午五点多，你一般下班后会做些什么呢？ '
                    'The quick brown fox jumps over the lazy dog 0123456789',
                    style: TextStyle(
                      color: i.isEven ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            if (bands > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 200,
                child: IgnorePointer(
                  child: ProgressiveBlur(
                    maxBlurRadius: 24,
                    startOffset: 0.3,
                    bands: bands,
                    debugShowMask: _mask,
                  ),
                ),
              ),
            Positioned(
              top: 48,
              left: 16,
              child: Row(
                spacing: 8,
                children: <Widget>[
                  _Chip(
                    label: 'bands $bands',
                    onTap: () => setState(
                      () => _bandIndex = (_bandIndex + 1) % _bandSteps.length,
                    ),
                  ),
                  _Chip(
                    label: _mask ? 'mask on' : 'mask off',
                    onTap: () => setState(() => _mask = !_mask),
                  ),
                  _Chip(
                    label: _autoScroll ? 'scrolling' : 'still',
                    onTap: _toggleAutoScroll,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(color: Colors.black)),
    ),
  );
}
