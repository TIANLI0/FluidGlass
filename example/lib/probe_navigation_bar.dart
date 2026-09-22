// Probe: a LiquidNavigationBar with all three islands and a long identity
// title, pinned to the liquid tier, over a scrolling list.
//
//   flutter run -t lib/probe_navigation_bar.dart -d <device>

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

void main() {
  GlassDeviceTier.instance.pinnedQuality = GlassQuality.liquid;
  runApp(const _ProbeApp());
}

class _ProbeApp extends StatefulWidget {
  const _ProbeApp();

  @override
  State<_ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<_ProbeApp> {
  final LayerBackdrop _backdrop = LayerBackdrop();
  String _log = '';

  @override
  void dispose() {
    _backdrop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFAF7F2),
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: BackdropLayer(
                backdrop: _backdrop,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 120, 16, 400),
                  itemCount: 100,
                  itemBuilder: (BuildContext context, int i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: i.isEven
                            ? const Color(0xFFFFFFFF)
                            : const Color(0xFFE77A52),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '第 $i 行 · Rust也是一门非常迷人的语言呢，它以内存安全和高性能著称。',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: -44,
                    child: IgnorePointer(
                      child: ProgressiveBlur(
                        maxBlurRadius: 24,
                        startOffset: 0.3,
                      ),
                    ),
                  ),
                  LiquidNavigationBar(
                    backdrop: _backdrop,
                    fadeHeight: 0,
                    scrimColor: Colors.transparent,
                    blurRadius: 24,
                    surfaceColor: const Color(
                      0xFFF2EEE8,
                    ).withValues(alpha: 0.74),
                    titleAlignment: Alignment.centerLeft,
                    titleMinWidth: 0,
                    titlePadding: const EdgeInsets.only(right: 16),
                    titleLeading: const CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xFF4A6FA5),
                      child: Text('千', style: TextStyle(color: Colors.white)),
                    ),
                    title: const Text('千尋-CouCou Club and a very long name'),
                    onTitlePressed: () => setState(() => _log = 'title'),
                    leading: LiquidNavigationAction(
                      backdrop: _backdrop,
                      icon: Icons.arrow_back_ios_new,
                      label: 'Back',
                      onPressed: () => setState(() => _log = 'back'),
                    ),
                    trailing: LiquidNavigationAction(
                      backdrop: _backdrop,
                      icon: Icons.phone,
                      label: 'Call',
                      onPressed: () => setState(() => _log = 'call'),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 40,
              left: 16,
              child: Row(
                spacing: 16,
                children: <Widget>[
                  Text('fired: $_log', style: const TextStyle(fontSize: 20)),
                  // **Push, do not just look.** The bar's screen limit comes
                  // from its paint transform, and a route slides the whole
                  // page across without rebuilding anything inside it — so a
                  // bar measured mid-slide once kept a limit short by however
                  // far it still had to travel, and ended in a straight
                  // vertical cut for the life of that page. It looked perfect
                  // until you navigated to it.
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _ProbeApp(),
                      ),
                    ),
                    child: const Text('push'),
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
