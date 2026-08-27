import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Pinned glass chrome over a feed that scrolls underneath it.
///
/// Every other screen in this catalog puts glass over a still wallpaper, which
/// is the cheap case: the backdrop snapshot stays valid and the glass only
/// re-samples it. This is the opposite, and the one real apps live in — a
/// header and a tab bar that stay put while the content behind them repaints
/// every frame, so `RenderBackdropLayer` invalidates and re-captures its
/// snapshot on every frame of the scroll. It is the most expensive thing this
/// library does, and the reason [GlassQuality] and [BackdropLayer.pixelRatio]
/// exist.
///
/// Note where the [BackdropLayer] sits: around the *scrolling* content. The
/// chrome is a sibling painted over it, not inside it — glass cannot refract
/// something it is part of.
///
/// The readout shows what this scroll actually costs, and the capture buttons
/// are the lever worth knowing about. Measured on a 120 Hz phone, flinging this
/// feed (mean ms per frame):
///
/// |                  | raster | build | total |
/// | ---------------- | ------ | ----- | ----- |
/// | no glass at all  | 0.73   | 0.20  | 1.49  |
/// | glass, capture 1 | 1.46   | 0.68  | 14.17 |
/// | glass, capture ½ | 2.05   | 1.20  | 5.37  |
///
/// Note what that says: raster and build are both tiny, and `totalSpan` is
/// twelve milliseconds larger than the two of them together. The cost is not
/// work, it is the stall from `toImageSync` — a synchronous capture in the
/// middle of a frame — and it scales with the number of pixels captured, not
/// with how much glass is drawn. So halving the capture is worth 2.5× here
/// while making almost no visible difference, because the glass blurs what it
/// samples anyway. Hence the ½ default; try `full` while flinging to feel it.
///
/// The tier does not move while you watch — quality is a property of the
/// device, decided before the first frame.
class AppChromeContent extends StatefulWidget {
  const AppChromeContent({super.key});

  @override
  State<AppChromeContent> createState() => _AppChromeContentState();
}

class _AppChromeContentState extends State<AppChromeContent> {
  final LayerBackdrop _backdrop = LayerBackdrop();
  final ScrollController _scroll = ScrollController();

  int _tab = 0;

  /// Half resolution by default, which is the measured difference between this
  /// screen being smooth and not. See the class doc.
  double? _captureRatio = 0.5;

  final List<int> _raster = <int>[];
  int _p90Micros = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    GlassDeviceTier.instance.addListener(_onQuality);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    GlassDeviceTier.instance.removeListener(_onQuality);
    _scroll.dispose();
    _backdrop.dispose();
    super.dispose();
  }

  void _onQuality() {
    if (mounted) setState(() {});
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final FrameTiming timing in timings) {
      _raster.add(timing.rasterDuration.inMicroseconds);
    }
    if (_raster.length < 30) return;
    final List<int> sorted = List<int>.of(_raster)..sort();
    _p90Micros = sorted[(sorted.length * 0.9).floor()];
    _raster.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color contentColor =
        isLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final EdgeInsets viewPadding = MediaQuery.paddingOf(context);

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // What the chrome refracts: the whole scrolling feed. Everything the
        // glass should see has to be inside here.
        Positioned.fill(
          child: BackdropLayer(
            backdrop: _backdrop,
            pixelRatio: _captureRatio,
            child: _Feed(
              controller: _scroll,
              topInset: viewPadding.top + 64,
              bottomInset: viewPadding.bottom + 132,
            ),
          ),
        ),

        // Pinned header.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _Header(
            backdrop: _backdrop,
            contentColor: contentColor,
            topInset: viewPadding.top,
          ),
        ),

        // The readout, itself on glass, so it is part of the load it measures.
        Positioned(
          top: viewPadding.top + 76,
          right: 12,
          child: _Readout(
            contentColor: contentColor,
            backdrop: _backdrop,
            p90Micros: _p90Micros,
            captureRatio: _captureRatio,
            onCaptureRatio: (double? ratio) =>
                setState(() => _captureRatio = ratio),
          ),
        ),

        // Pinned tab bar — the case that prompted this screen.
        Positioned(
          left: 16,
          right: 16,
          bottom: 16 + viewPadding.bottom,
          child: LiquidBottomTabs(
            selectedTabIndex: _tab,
            onTabSelected: (int index) => setState(() => _tab = index),
            backdrop: _backdrop,
            tabsCount: 3,
            children: <Widget>[
              for (final (IconData icon, String label) tab in const <(
                IconData,
                String
              )>[
                (Icons.photo_library_outlined, 'Feed'),
                (Icons.search, 'Search'),
                (Icons.person_outline, 'You'),
              ])
                LiquidBottomTab(
                  onPressed: () => setState(
                    () => _tab = <String>['Feed', 'Search', 'You']
                        .indexOf(tab.$2),
                  ),
                  children: <Widget>[
                    Icon(tab.$1, size: 26, color: contentColor),
                    Text(
                      tab.$2,
                      style: TextStyle(color: contentColor, fontSize: 12),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A feed of full-bleed rows carrying fine detail.
///
/// Both properties are deliberate, and the screen was wrong twice before it
/// had them:
///
/// * **Full bleed.** Inset cards with rounded corners sat almost exactly under
///   the tab bar's own inset capsule, two nearly-concentric rounded rectangles
///   in the same hue, and the glass edge became unreadable — it looked like the
///   border was not being drawn at all.
/// * **Fine detail.** Smooth gradients are their own blur: blurring one gives
///   back almost the same pixels, so the chrome looked like it was only
///   blurring the text. Small type, hairlines and small shapes are what make a
///   blur legible as a blur.
class _Feed extends StatelessWidget {
  const _Feed({
    required this.controller,
    required this.topInset,
    required this.bottomInset,
  });

  final ScrollController controller;
  final double topInset;
  final double bottomInset;

  static const List<Color> _accents = <Color>[
    Color(0xFF0088FF),
    Color(0xFFE5484D),
    Color(0xFF00A972),
    Color(0xFF8E5BFF),
    Color(0xFFF2A100),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
      itemCount: 60,
      itemBuilder: (BuildContext context, int index) {
        // Every seventh row is photographic, so the glass has real image detail
        // to work on as well as type.
        if (index % 7 == 6) {
          return SizedBox(
            height: 200,
            width: double.infinity,
            child: Image.asset(
              'assets/wallpaper_light.webp',
              fit: BoxFit.cover,
              alignment: Alignment(0, (index / 60) * 2 - 1),
            ),
          );
        }
        return _Row(index: index, accent: _accents[index % _accents.length]);
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.index, required this.accent});

  final int index;
  final Color accent;

  static const String _body =
      'Fine text at a small size is what makes a blur read as a blur — a '
      'smooth gradient blurred is very nearly itself, so it proves nothing. '
      'Hairlines and small type are the honest test.';

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color ink =
        isLight ? const Color(0xFF101010) : const Color(0xFFF2F2F2);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF101014),
        border: Border(
          bottom: BorderSide(color: ink.withValues(alpha: 0.10), width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: <Widget>[
            // A small saturated shape, for colour the blur can smear.
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: <Color>[accent, accent.withValues(alpha: 0.55)],
                ),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: <Widget>[
                  Text(
                    'Row ${index + 1} — pinned chrome over live content',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _body,
                    maxLines: 3,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.62),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  // Hairlines: the first thing a blur destroys.
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      spacing: 3,
                      children: <Widget>[
                        for (int i = 0; i < 26; i++)
                          Container(
                            width: 1,
                            height: 10,
                            color: ink.withValues(alpha: 0.30),
                          ),
                      ],
                    ),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.backdrop,
    required this.contentColor,
    required this.topInset,
  });

  final Backdrop backdrop;
  final Color contentColor;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return LiquidPanel(
      backdrop: backdrop,
      // Square top corners: the bar runs into the status bar rather than
      // floating, which is what app chrome actually looks like.
      shape: const UnevenRoundedRectangle(
        RectangleCornerRadii(
          topStart: 0,
          topEnd: 0,
          bottomEnd: 28,
          bottomStart: 28,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: topInset, left: 20, right: 12, bottom: 14),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Feed',
                style: TextStyle(
                  color: contentColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.notifications_none, color: contentColor, size: 24),
          ],
        ),
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.contentColor,
    required this.backdrop,
    required this.p90Micros,
    required this.captureRatio,
    required this.onCaptureRatio,
  });

  final Color contentColor;
  final Backdrop backdrop;
  final int p90Micros;
  final double? captureRatio;
  final ValueChanged<double?> onCaptureRatio;

  @override
  Widget build(BuildContext context) {
    final GlassDeviceTier tier = GlassDeviceTier.instance;
    final double refreshRate = tier.info.refreshRate;
    final int budget =
        refreshRate > 0 ? (1000000 / refreshRate).round() : 16667;

    return LiquidPanel(
      backdrop: backdrop,
      shape: const RoundedRectangle(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'tier ${tier.quality.name}',
              style: TextStyle(
                color: contentColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              p90Micros == 0
                  ? 'scroll to measure'
                  : 'raster p90 ${(p90Micros / 1000).toStringAsFixed(1)} / '
                      '${(budget / 1000).toStringAsFixed(1)} ms',
              style: TextStyle(
                color: contentColor.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'capture',
              style: TextStyle(
                color: contentColor.withValues(alpha: 0.55),
                fontSize: 11,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final (double?, String) option in const <(double?, String)>[
                  (null, 'full'),
                  (0.5, '½'),
                  (0.25, '¼'),
                ])
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onCaptureRatio(option.$1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      child: Text(
                        option.$2,
                        style: TextStyle(
                          color: option.$1 == captureRatio
                              ? const Color(0xFF0088FF)
                              : contentColor.withValues(alpha: 0.6),
                          fontSize: 14,
                          fontWeight: option.$1 == captureRatio
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
