import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../fluid_glass.dart';

/// Top chrome as three islands of glass over a scrim of the page colour — a
/// leading action, a title that hugs its content, a trailing action — drawn as
/// one fused body.
///
/// Not a bar. A full-width pane has to be tinted hard enough to carry text
/// across its whole width, which makes it a solid bar with a blurred edge;
/// islands only cover what they hold, so the content keeps scrolling visibly
/// between them. What stops the gaps reading as holes is [scrimColor]: opaque
/// behind the status bar, near-opaque across the islands, gone [fadeHeight]
/// below them.
///
/// The three islands are one [LiquidFusion]: one capture of the backdrop and
/// one shader pass for the whole chrome, a silhouette that merges where the
/// islands come close — a long title reaches the actions beside it instead of
/// colliding with them — and one light, so a press travels as far as the body
/// it is in and no further.
///
/// The geometry is *computed*, not measured off the widgets: this bar knows
/// where its own slots go, so the field is told the three rectangles directly.
/// A field that reads its shapes out of other render objects while it paints
/// is a field that draws them a frame late, which is what a fused chrome
/// cannot afford — the glass would lag the icons sitting on it.
///
/// Place above the backdrop content in a Stack. Everything but the islands
/// ignores input, so content underneath still scrolls and still takes taps.
///
/// ```dart
/// LiquidNavigationBar(
///   backdrop: backdrop,
///   leading: LiquidNavigationAction(
///     backdrop: backdrop,
///     icon: Icons.arrow_back_ios_new,
///     label: 'Back',
///     onPressed: () => Navigator.maybePop(context),
///   ),
///   titleLeading: const CircleAvatar(radius: 16),
///   title: const Text('Mika'),
///   onTitlePressed: openProfile,
///   trailing: moreButton,
/// )
/// ```
class LiquidNavigationBar extends StatefulWidget
    implements PreferredSizeWidget {
  const LiquidNavigationBar({
    super.key,
    required this.backdrop,
    required this.title,
    this.titleLeading,
    this.onTitlePressed,
    this.leading,
    this.trailing,
    this.height = 48,
    this.slotWidth,
    this.titleMinWidth = 144,
    this.fadeHeight = 24,
    this.smoothing = 10,
    this.surfaceColor,
    this.scrimColor,
    this.includeTopPadding = true,
  }) : assert(height >= 48, 'An island holds a touch target; 48 is the floor.'),
       assert(fadeHeight >= 0),
       assert(titleMinWidth >= 0);

  /// What the islands refract — the scrolling content they sit over.
  final Backdrop backdrop;

  /// The island label. Ellipsised, so a long name shortens rather than growing
  /// the island past the space between the side slots.
  final Widget title;

  /// Sits inside the island, before [title] — an avatar, a status dot.
  final Widget? titleLeading;

  /// Makes the island a button, the way a chat header opens the profile it
  /// names. Null leaves it a label.
  final VoidCallback? onTitlePressed;

  /// The side actions. Each gets a [slotWidth] slot, and the two slots are the
  /// same width whatever they hold, which is what keeps [title] centred on the
  /// screen rather than between its neighbours.
  ///
  /// [LiquidNavigationAction] is the matching action: inside this bar it draws
  /// no glass of its own, because the bar is already drawing it.
  final Widget? leading, trailing;

  /// The islands height, and so the side actions diameter.
  final double height;

  /// The width reserved for each side action. Defaults to [height] — one round
  /// button. Widen it for a slot holding two.
  final double? slotWidth;

  /// Keeps the island from shrinking around a one-word title until it looks
  /// like a chip. Zero lets it hug.
  final double titleMinWidth;

  /// How far below the islands the scrim takes to disappear. Zero ends it on a
  /// hard line under the chrome, which is what this exists to avoid.
  final double fadeHeight;

  /// How close the islands have to come before they merge — see
  /// [LiquidFusion.smoothing]. At the default they merge only once a long
  /// title has grown the middle island to within a few pixels of an action.
  final double smoothing;

  /// The islands tint over the refracted backdrop. Defaults to
  /// [chromeSurfaceOf].
  final Color? surfaceColor;

  /// The page colour the chrome sits on. Defaults to the enclosing
  /// [ColorScheme.surface] — the page own background bleeding up behind the
  /// status bar, not a glass colour.
  final Color? scrimColor;

  /// Whether the bar leaves room for the status bar itself. Pass false when a
  /// parent [SafeArea] already did.
  final bool includeTopPadding;

  /// The gap between the islands, and the inset around them.
  static const double _gap = 8;

  /// The tint chrome carries, for a caller building an island of its own.
  ///
  /// The palette [LiquidGlassColors.container] as it stands, which is what a
  /// [LiquidMenu] panel carries — the tint a row of a menu is legible against.
  /// It is deliberately light: what makes chrome readable is the blur under
  /// it, not the paint over it. Raising the alpha instead is how glass turns
  /// into a grey bar.
  static Color chromeSurfaceOf(BuildContext context) =>
      LiquidGlassTheme.of(context).container;

  /// How hard the chrome blurs what it sits over.
  ///
  /// A menu panel blurs at 8 and is legible over anything; a button blurs at 2
  /// because it sits over a photograph where the point is to see through it.
  /// Chrome sits over running text, so it takes the panel value.
  static const double chromeBlur = 8;

  @override
  Size get preferredSize => Size.fromHeight(height + _gap * 2 + fadeHeight);

  @override
  State<LiquidNavigationBar> createState() => _LiquidNavigationBarState();
}

/// Which island a press belongs to.
enum _Slot { leading, title, trailing }

/// What a finger is doing to one island.
@immutable
class _Press {
  const _Press({
    required this.slot,
    required this.local,
    required this.travel,
    required this.progress,
    required this.radius,
  });

  final _Slot slot;

  /// Where the finger is, in the island own coordinates.
  final Offset local;

  /// How far it has travelled since it went down — what the deformation law
  /// leans and stretches by.
  final Offset travel;

  final double progress;
  final double radius;

  @override
  bool operator ==(Object other) =>
      other is _Press &&
      other.slot == slot &&
      other.local == local &&
      other.travel == travel &&
      other.progress == progress &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(slot, local, travel, progress, radius);
}

class _LiquidNavigationBarState extends State<LiquidNavigationBar> {
  /// The press the chrome is under, or null at rest.
  ///
  /// Rebuilding the chrome on every frame of a press is deliberate: the shape
  /// the field is told has to be the shape the press has deformed it into, and
  /// the way to keep those two from ever disagreeing is for both to be worked
  /// out in the same build from the same numbers. The alternative — geometry
  /// read later, out of whatever the widgets happen to be doing — is what put
  /// the glass a frame behind the icons on it.
  _Press? _press;

  /// Where each island ended up this build, so an action reporting a press in
  /// its own coordinates can be put in the bar coordinates.
  final Map<_Slot, Rect> _rects = <_Slot, Rect>{};

  /// The title island width, measured from what it holds.
  double _titleWidth = 0;

  void _report(
    _Slot slot,
    Offset local,
    Offset travel,
    double progress,
    double radius,
  ) {
    final _Press? next = progress <= 0
        ? null
        : _Press(
            slot: slot,
            local: local,
            travel: travel,
            progress: progress,
            radius: radius,
          );
    if (next == null && _press?.slot != slot) return;
    if (next == _press) return;
    setState(() => _press = next);
  }

  /// The island rectangle with the press applied — the same lean and squash a
  /// [LiquidButton] writes onto its own glass layer, here written onto the
  /// shape the field draws, so the glass moves with the finger instead of
  /// sitting still while the icon on it moves.
  Rect _deformed(Rect rect, _Press press) {
    final LiquidPressDeformation law = LiquidPressDeformation.resolve(
      rect.size,
      offset: press.travel,
      pressProgress: press.progress,
    );
    if (law.isIdentity) return rect;
    return Rect.fromCenter(
      center: rect.center.translate(law.translationX, law.translationY),
      width: rect.width * law.scaleX,
      height: rect.height * law.scaleY,
    );
  }

  void _measureTitle(Size size) {
    if ((size.width - _titleWidth).abs() < 0.5) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _titleWidth = size.width);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double top = widget.includeTopPadding
        ? MediaQuery.paddingOf(context).top
        : 0;
    final Color scrim =
        widget.scrimColor ?? Theme.of(context).colorScheme.surface;
    final double gap = LiquidNavigationBar._gap;
    final double chrome = top + widget.height + gap * 2;
    final double total = chrome + widget.fadeHeight;

    return SizedBox(
      height: total,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      scrim,
                      scrim,
                      scrim.withValues(alpha: 0.94),
                      scrim.withValues(alpha: 0),
                    ],
                    // Solid behind the status bar, still carrying across the
                    // islands, and only then on its way out.
                    stops: <double>[
                      0,
                      (top / total).clamp(0.0, 1.0),
                      (chrome / total).clamp(0.0, 1.0),
                      1,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  _buildChrome(context, constraints.maxWidth, top, gap),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChrome(
    BuildContext context,
    double width,
    double top,
    double gap,
  ) {
    final Color content = LiquidGlassTheme.of(context).content;
    final Color surface =
        widget.surfaceColor ?? LiquidNavigationBar.chromeSurfaceOf(context);
    final double slot = widget.slotWidth ?? widget.height;
    final double height = widget.height;
    final double y = top + gap;
    final bool hasLeading = widget.leading != null;
    final bool hasTrailing = widget.trailing != null;

    // Symmetric slots whatever they hold, which is what keeps the title
    // centred on the screen rather than between its neighbours.
    final double room = math.max(width - (16 + slot + gap) * 2, 0);
    final double titleWidth = math.min(
      math.max(_titleWidth, widget.titleMinWidth),
      room,
    );

    final Rect leadingRect = Rect.fromLTWH(16, y, slot, height);
    final Rect trailingRect = Rect.fromLTWH(width - 16 - slot, y, slot, height);
    final Rect titleRect = Rect.fromCenter(
      center: Offset(width / 2, y + height / 2),
      width: math.max(titleWidth, 0),
      height: height,
    );
    _rects
      ..[_Slot.leading] = leadingRect
      ..[_Slot.title] = titleRect
      ..[_Slot.trailing] = trailingRect;

    final _Press? press = _press;
    Rect shapeOf(_Slot slot, Rect rect) =>
        press == null || press.slot != slot ? rect : _deformed(rect, press);
    final Rect? pressedRect = press == null ? null : _rects[press.slot];

    return LiquidFusion(
      backdrop: widget.backdrop,
      smoothing: widget.smoothing,
      surfaceColor: surface,
      blurRadius: LiquidNavigationBar.chromeBlur,
      // The light carries the width of the chrome, so a press on one island is
      // felt on the other two — on them, never in the gaps, because the field
      // is what masks it.
      press: press == null || pressedRect == null
          ? null
          : LiquidFusionPress(
              position: pressedRect.topLeft + press.local,
              progress: press.progress,
              radius: press.radius,
              reach: width,
              owner: press.slot,
            ),
      blobs: <LiquidBlob>[
        if (hasLeading) LiquidBlob(shapeOf(_Slot.leading, leadingRect)),
        LiquidBlob(shapeOf(_Slot.title, titleRect)),
        if (hasTrailing) LiquidBlob(shapeOf(_Slot.trailing, trailingRect)),
      ],
      children: <Widget>[
        if (hasLeading)
          Positioned.fromRect(
            rect: leadingRect,
            child: _ChromeSlot(
              slot: _Slot.leading,
              report: _report,
              child: widget.leading!,
            ),
          ),
        Positioned.fromRect(
          rect: titleRect,
          child: _ChromeSlot(
            slot: _Slot.title,
            report: _report,
            child: _TitleIsland(
              title: widget.title,
              titleLeading: widget.titleLeading,
              onPressed: widget.onTitlePressed,
              content: content,
              onMeasured: _measureTitle,
            ),
          ),
        ),
        if (hasTrailing)
          Positioned.fromRect(
            rect: trailingRect,
            child: _ChromeSlot(
              slot: _Slot.trailing,
              report: _report,
              child: widget.trailing!,
            ),
          ),
      ],
    );
  }
}

/// Tells whatever is in a slot that the chrome is drawing the glass, and where
/// to report a press.
class _ChromeSlot extends InheritedWidget {
  const _ChromeSlot({
    required this.slot,
    required this.report,
    required super.child,
  });

  final _Slot slot;
  final void Function(
    _Slot slot,
    Offset local,
    Offset travel,
    double progress,
    double radius,
  )
  report;

  static _ChromeSlot? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ChromeSlot>();

  @override
  bool updateShouldNotify(_ChromeSlot oldWidget) =>
      oldWidget.slot != slot || oldWidget.report != report;
}

/// The title island content: an avatar and a label, sized to what it holds.
class _TitleIsland extends StatelessWidget {
  const _TitleIsland({
    required this.title,
    required this.titleLeading,
    required this.onPressed,
    required this.content,
    required this.onMeasured,
  });

  final Widget title;
  final Widget? titleLeading;
  final VoidCallback? onPressed;
  final Color content;
  final ValueChanged<Size> onMeasured;

  @override
  Widget build(BuildContext context) {
    final Widget label = DefaultTextStyle(
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: content,
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: title,
    );

    return Semantics(
      header: onPressed == null,
      button: onPressed != null,
      child: _ChromePress(
        onPressed: onPressed,
        child: Center(
          child: _MeasureWidth(
            onMeasured: onMeasured,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: <Widget>[
                  ?titleLeading,
                  Flexible(child: label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reports the width its child wants, so the bar can give the island a
/// rectangle that fits it.
///
/// One frame late by construction, and that is why it is allowed here: an
/// island changes width when its title changes, which does not happen while
/// anything is moving. Positions — the part that would visibly lag — are
/// arithmetic, not measurement.
class _MeasureWidth extends SingleChildRenderObjectWidget {
  const _MeasureWidth({required this.onMeasured, required Widget super.child});

  final ValueChanged<Size> onMeasured;

  @override
  _RenderMeasureWidth createRenderObject(BuildContext context) =>
      _RenderMeasureWidth(onMeasured);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureWidth renderObject,
  ) {
    renderObject.onMeasured = onMeasured;
  }
}

class _RenderMeasureWidth extends RenderProxyBox {
  _RenderMeasureWidth(this.onMeasured);

  ValueChanged<Size> onMeasured;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (_last == size) return;
    _last = size;
    onMeasured(size);
  }
}

/// The press an island answers with, when the glass is not its own to draw.
///
/// Everything a [LiquidButton] does with a press except the glass: the same
/// squash and lean from [LiquidPressDeformation], the same slop-free tap, and
/// the glow handed to the chrome so the fused body draws it — in the body,
/// where it can cross a neck into an island that has merged and cannot cross a
/// gap to one that has not.
class _ChromePress extends StatefulWidget {
  const _ChromePress({required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  State<_ChromePress> createState() => _ChromePressState();
}

class _ChromePressState extends State<_ChromePress>
    with TickerProviderStateMixin {
  late final InteractiveHighlight _highlight = InteractiveHighlight(
    vsync: this,
  );
  _ChromeSlot? _chrome;

  @override
  void initState() {
    super.initState();
    _highlight.addListener(_publish);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chrome = _ChromeSlot.maybeOf(context);
  }

  @override
  void dispose() {
    _highlight.removeListener(_publish);
    _highlight.dispose();
    super.dispose();
  }

  void _publish() {
    final _ChromeSlot? chrome = _chrome;
    if (chrome == null) return;
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    chrome.report(
      chrome.slot,
      _highlight.glowPosition(box.size),
      _highlight.offset,
      _highlight.pressProgress,
      box.size.shortestSide * 1.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onPressed == null) return widget.child;
    return _highlight.wrapGestures(
      onTap: widget.onPressed,
      child: _PressDeformation(highlight: _highlight, child: widget.child),
    );
  }
}

/// Moves an island content with the press, the way a glass element moves with
/// its layer.
class _PressDeformation extends StatelessWidget {
  const _PressDeformation({required this.highlight, required this.child});

  final InteractiveHighlight highlight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        return AnimatedBuilder(
          animation: highlight,
          builder: (BuildContext context, Widget? inner) {
            final LiquidPressDeformation press = LiquidPressDeformation.resolve(
              size,
              offset: highlight.offset,
              pressProgress: highlight.pressProgress,
            );
            if (press.isIdentity) return inner!;
            return Transform(
              transform: press.transform,
              alignment: Alignment.center,
              child: inner,
            );
          },
          child: child,
        );
      },
    );
  }
}

/// A round action for [LiquidNavigationBar] side slots.
///
/// Inside the bar it draws no glass of its own — the bar draws all three
/// islands as one body — and keeps everything else a button has: the press
/// squash, the slop-free tap, and a glow handed to the chrome so the fused
/// body lights it. Outside a bar it is an ordinary [LiquidButton].
class LiquidNavigationAction extends StatelessWidget {
  const LiquidNavigationAction({
    super.key,
    required this.backdrop,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 48,
    this.iconSize = 22,
    this.surfaceColor,
  }) : assert(size >= 48, 'Touch targets stay at least 48.');

  final Backdrop backdrop;
  final IconData icon;

  /// What it does, for the screen reader — an icon on its own says nothing.
  final String label;

  /// Null disables it, as everywhere else.
  final VoidCallback? onPressed;

  final double size, iconSize;

  /// Only used outside a bar, where this draws its own glass.
  final Color? surfaceColor;

  @override
  Widget build(BuildContext context) {
    final Color content = LiquidGlassTheme.of(context).content;
    final Widget glyph = SizedBox(
      width: size,
      height: size,
      child: Icon(icon, size: iconSize, color: content),
    );

    final Widget button = _ChromeSlot.maybeOf(context) == null
        ? LiquidButton(
            backdrop: backdrop,
            onPressed: onPressed,
            surfaceColor:
                surfaceColor ?? LiquidNavigationBar.chromeSurfaceOf(context),
            height: size,
            padding: EdgeInsets.zero,
            children: <Widget>[glyph],
          )
        : _ChromePress(
            onPressed: onPressed,
            child: Center(child: glyph),
          );

    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: button,
    );
  }
}
