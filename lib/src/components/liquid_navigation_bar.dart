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
    this.blurRadius,
    this.isInteractive = true,
    this.titleAlignment = Alignment.center,
    this.titlePadding = const EdgeInsets.symmetric(horizontal: 16),
    this.includeTopPadding = true,
  }) : assert(height >= 48, 'An island holds a touch target; 48 is the floor.'),
       assert(fadeHeight >= 0),
       assert(titleMinWidth >= 0),
       assert(
         blurRadius == null || blurRadius >= 0,
         'A blur radius is a distance.',
       );

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

  /// How hard the islands blur what they sit over. Defaults to [chromeBlur].
  ///
  /// The one dial worth reaching for when chrome does not read against a
  /// particular app's content, and the one to reach for *first*: what makes
  /// chrome legible is the blur under it, not the paint over it, so raising
  /// this costs nothing but a wider sample where raising [surfaceColor]'s
  /// alpha costs the glass. A page of running text under the bar wants more
  /// than a page of photographs does.
  final double? blurRadius;

  /// Where the title content sits inside its island.
  ///
  /// Centre is right for a title that names a page. Left is right for an
  /// identity — an avatar and a name read as one object starting at the same
  /// edge, the way a conversation header does, and the island keeps its
  /// [titleMinWidth] instead of shrink-wrapping around a short name.
  final AlignmentGeometry titleAlignment;

  /// The inset around the title content.
  ///
  /// Drop the leading side to zero for a [titleLeading] as tall as the island:
  /// a round avatar of exactly [height] then shares its circle with the
  /// island's own rounded cap, rather than floating inside it.
  final EdgeInsetsGeometry titlePadding;

  /// False keeps every tap and drops everything that moves — the squash, the
  /// lean and the glow travelling through the body — for a platform asking
  /// for reduced motion.
  ///
  /// It reaches every island, the actions passed in included: the bar owns
  /// the finger its islands answer to, so an action cannot go on deforming
  /// in a bar that has stopped tracking one. An action can still turn the
  /// motion off on its own through its own flag.
  final bool isInteractive;

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

  /// The one finger the chrome answers, published to the islands.
  ///
  /// **The bar owns the gesture, not the islands.** Each island used to run
  /// its own slop-free tap: press the back button, slide onto the title, lift
  /// — and the light had crossed the body while the tap had not, because the
  /// island that saw the down was the only one that could fire. A body of
  /// glass that carries a press from one island to the next has to carry the
  /// *commit* with it, or the light is lying about what the finger can do.
  /// So one listener over the whole chrome tracks the finger, tells the
  /// island it is over to light up and lean, and on release tells that island
  /// — whichever it is by then — to fire. Lifting in a gap fires nothing.
  final _ChromeTouch _touch = _ChromeTouch();

  /// The pointer being tracked, so a second finger is ignored.
  int? _pointer;

  bool _hasLeading = false;
  bool _hasTrailing = false;

  @override
  void dispose() {
    _touch.dispose();
    super.dispose();
  }

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
    // While the finger is on one island, the island it just left is still
    // reporting its spring settling back to zero. Those reports would flip
    // the body's light between the two islands every frame; the light
    // belongs to the island under the finger.
    final _Slot? held = _touch.slot;
    if (next != null && held != null && held != slot) return;
    if (next == null && _press?.slot != slot) return;
    if (next == _press) return;
    setState(() => _press = next);
  }

  /// The island under [position] (chrome coordinates), or null in a gap.
  _Slot? _slotAt(Offset position) {
    for (final MapEntry<_Slot, Rect> entry in _rects.entries) {
      if (entry.key == _Slot.leading && !_hasLeading) continue;
      if (entry.key == _Slot.trailing && !_hasTrailing) continue;
      if (entry.value.contains(position)) return entry.key;
    }
    return null;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    final _Slot? slot = _slotAt(event.localPosition);
    if (slot == null) return;
    _pointer = event.pointer;
    _touch.update(slot: slot, position: event.localPosition);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    // Over a gap the finger keeps the island it came from: the light has
    // nowhere else to be, and a release there still fires nothing.
    _touch.update(
      slot: _slotAt(event.localPosition) ?? _touch.slot,
      position: event.localPosition,
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _touch.release(
      slot: _slotAt(event.localPosition),
      position: event.localPosition,
    );
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _touch.release(slot: null, position: event.localPosition);
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
          // A fully transparent scrim is "no scrim", not a scrim of that
          // colour's RGB. `Colors.transparent` is black at alpha 0, and
          // `withValues(alpha: 0.94)` on it is 94% black: an app that handed
          // the scrim to something else — a progressive blur under the bar —
          // got a slab darkening towards the islands' bottom edge instead,
          // and nothing threw. The ramp's alphas scale the caller's alpha, so
          // a half-transparent page colour fades from half, and zero is
          // nothing at all.
          if (scrim.a > 0)
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
                        scrim.withValues(alpha: scrim.a * 0.94),
                        scrim.withValues(alpha: 0),
                      ],
                      // Solid behind the status bar, still carrying across
                      // the islands, and only then on its way out.
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

    _hasLeading = hasLeading;
    _hasTrailing = hasTrailing;
    // Leading and trailing are ends of the reading direction, not of the
    // screen: in a right-to-left layout the back action sits on the right,
    // where the title's own alignment and padding already put its start.
    final bool isLtr =
        (Directionality.maybeOf(context) ?? TextDirection.ltr) ==
        TextDirection.ltr;
    final Rect startRect = Rect.fromLTWH(16, y, slot, height);
    final Rect endRect = Rect.fromLTWH(width - 16 - slot, y, slot, height);
    final Rect leadingRect = isLtr ? startRect : endRect;
    final Rect trailingRect = isLtr ? endRect : startRect;
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

    final Widget body = LiquidFusion(
      backdrop: widget.backdrop,
      smoothing: widget.smoothing,
      surfaceColor: surface,
      blurRadius: widget.blurRadius ?? LiquidNavigationBar.chromeBlur,
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
              rect: leadingRect,
              report: _report,
              touch: _touch,
              interactive: widget.isInteractive,
              child: widget.leading!,
            ),
          ),
        Positioned.fromRect(
          rect: titleRect,
          child: _ChromeSlot(
            slot: _Slot.title,
            rect: titleRect,
            report: _report,
            touch: _touch,
            interactive: widget.isInteractive,
            child: _TitleIsland(
              title: widget.title,
              titleLeading: widget.titleLeading,
              onPressed: widget.onTitlePressed,
              isInteractive: widget.isInteractive,
              alignment: widget.titleAlignment,
              padding: widget.titlePadding,
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
              rect: trailingRect,
              report: _report,
              touch: _touch,
              interactive: widget.isInteractive,
              child: widget.trailing!,
            ),
          ),
      ],
    );
    if (!widget.isInteractive) return body;
    // Translucent: the gaps between islands still pass taps to the content
    // beneath, and the islands stay opaque hit targets of their own (see
    // `_ChromePress`), so a tap on one never also lands on a message under it.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: body,
    );
  }
}

/// The finger the bar is tracking, as the islands see it: which island it is
/// over, where it is in chrome coordinates, and — for one notification — that
/// it has just lifted.
class _ChromeTouch extends ChangeNotifier {
  _Slot? _slot;
  Offset _position = Offset.zero;
  bool _released = false;

  /// The island under the finger, or the last one it was over; null at rest.
  _Slot? get slot => _slot;

  /// Where the finger is, in the chrome's coordinates.
  Offset get position => _position;

  /// True only during the notification for a lift: the island in [slot] fires,
  /// every island lets go of its press.
  bool get released => _released;

  void update({required _Slot? slot, required Offset position}) {
    if (slot == _slot && position == _position && !_released) return;
    _slot = slot;
    _position = position;
    _released = false;
    notifyListeners();
  }

  /// The finger lifted over [slot] (null: over nothing, or the gesture was
  /// taken away). After the islands have heard it the touch is at rest.
  void release({required _Slot? slot, required Offset position}) {
    _slot = slot;
    _position = position;
    _released = true;
    notifyListeners();
    _slot = null;
    _released = false;
  }
}

/// Tells whatever is in a slot that the chrome is drawing the glass: where its
/// island is, where to report a press, and which finger to follow.
class _ChromeSlot extends InheritedWidget {
  const _ChromeSlot({
    required this.slot,
    required this.rect,
    required this.report,
    required this.touch,
    required this.interactive,
    required super.child,
  });

  final _Slot slot;

  /// The island's rectangle in chrome coordinates — what turns the bar's
  /// finger position into the island's own.
  final Rect rect;

  final void Function(
    _Slot slot,
    Offset local,
    Offset travel,
    double progress,
    double radius,
  )
  report;

  final _ChromeTouch touch;

  /// The bar's [LiquidNavigationBar.isInteractive].
  ///
  /// With it false the bar installs no pointer listener, so [touch] never
  /// moves: an island that went on waiting for it would never fire.
  final bool interactive;

  static _ChromeSlot? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ChromeSlot>();

  @override
  bool updateShouldNotify(_ChromeSlot oldWidget) =>
      oldWidget.slot != slot ||
      oldWidget.rect != rect ||
      oldWidget.report != report ||
      oldWidget.touch != touch ||
      oldWidget.interactive != interactive;
}

/// The title island content: an avatar and a label, sized to what it holds.
class _TitleIsland extends StatelessWidget {
  const _TitleIsland({
    required this.title,
    required this.titleLeading,
    required this.onPressed,
    required this.isInteractive,
    required this.alignment,
    required this.padding,
    required this.content,
    required this.onMeasured,
  });

  final Widget title;
  final Widget? titleLeading;
  final VoidCallback? onPressed;
  final bool isInteractive;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry padding;
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
      onTap: onPressed,
      child: _ChromePress(
        onPressed: onPressed,
        isInteractive: isInteractive,
        child: Align(
          alignment: alignment,
          child: _MeasureWidth(
            onMeasured: onMeasured,
            child: Padding(
              padding: padding,
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
/// **It reports the intrinsic width, not the laid-out one.** The island's
/// rectangle is computed *from* this number, so measuring what the child was
/// given makes the two a fixed point that can never grow: an island handed
/// 144 lays its row out in 144, reports 144, and is handed 144 again — a
/// longer title is quietly ellipsised to the minimum width for ever, and a
/// minimum of zero collapses the island out of existence. Asking how wide the
/// content *wants* to be breaks the loop; the bar still clamps the answer to
/// the room between the side actions.
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
    final RenderBox? content = child;
    final Size measured = content == null
        ? size
        : Size(
            math.max(content.getMaxIntrinsicWidth(double.infinity), size.width),
            size.height,
          );
    if (_last == measured) return;
    _last = measured;
    onMeasured(measured);
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
  const _ChromePress({
    required this.onPressed,
    required this.child,
    this.isInteractive = true,
  });

  final VoidCallback? onPressed;

  /// False keeps the tap and drops everything that moves — the squash, the
  /// lean and the glow the chrome draws — for a platform asking for reduced
  /// motion. The island still answers a press, it just does not deform.
  final bool isInteractive;

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

  /// Whether the bar's finger is currently on this island.
  bool _held = false;

  @override
  void initState() {
    super.initState();
    _highlight.addListener(_publish);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final _ChromeSlot? next = _ChromeSlot.maybeOf(context);
    if (!identical(next?.touch, _chrome?.touch)) {
      _chrome?.touch.removeListener(_onTouch);
      next?.touch.addListener(_onTouch);
    }
    _chrome = next;
  }

  @override
  void dispose() {
    _chrome?.touch.removeListener(_onTouch);
    _highlight.removeListener(_publish);
    _highlight.dispose();
    super.dispose();
  }

  /// Whether this island deforms and glows: only when both it and the bar it
  /// sits in do.
  bool get _interactive =>
      widget.isInteractive && (_chrome?.interactive ?? true);

  /// The bar's finger moved, arrived, left or lifted.
  ///
  /// Arriving from a neighbouring island counts as a fresh press here — the
  /// lean is measured from where the finger entered, not from where it first
  /// touched the bar — and lifting over this island is what fires it, however
  /// far the finger has travelled since it went down.
  void _onTouch() {
    final _ChromeSlot? chrome = _chrome;
    if (chrome == null || !_interactive) return;
    final _ChromeTouch touch = chrome.touch;
    final bool mine = touch.slot == chrome.slot;
    final Offset local = touch.position - chrome.rect.topLeft;
    if (touch.released) {
      if (mine) widget.onPressed?.call();
      if (_held) {
        _held = false;
        _highlight.handleUp();
      }
      return;
    }
    if (mine) {
      if (_held) {
        _highlight.handleMove(local);
      } else {
        _held = true;
        _highlight.handleDown(local);
      }
    } else if (_held) {
      _held = false;
      _highlight.handleUp();
    }
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
    if (!_interactive) {
      final VoidCallback? onPressed = widget.onPressed;
      if (onPressed == null) return widget.child;
      return Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onPressed, child: widget.child),
      );
    }
    // An island answers a finger whether or not it does anything. A title that
    // only names the page is still part of the same body of glass, and a bar
    // whose two ends move under the finger while its middle sits dead reads as
    // a bug rather than as restraint. With no callback nothing fires; what the
    // touch buys is the deformation and the light travelling through the body.
    //
    // The pointer itself is the bar's (`_ChromeTouch`), so a press can travel
    // from one island to the next and fire the one it lifts on. This listener
    // has no handlers: it is here to be an opaque hit target, so a tap on an
    // island does not also reach whatever the island is drawn over.
    return Listener(
      behavior: HitTestBehavior.opaque,
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
            // Always a `Transform`, the identity at rest. Returning the bare
            // child there swapped the widget in this slot at the start and end
            // of every press, which tears the island's content down and builds
            // it again — an avatar's image, a badge's animation, any state
            // inside it lost twice per tap.
            return Transform(
              transform: press.isIdentity
                  ? Matrix4.identity()
                  : press.transform,
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
    this.isInteractive = true,
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

  /// False keeps the tap and drops the press deformation and glow, for a
  /// platform asking for reduced motion.
  final bool isInteractive;

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
            isInteractive: isInteractive,
            surfaceColor:
                surfaceColor ?? LiquidNavigationBar.chromeSurfaceOf(context),
            height: size,
            padding: EdgeInsets.zero,
            children: <Widget>[glyph],
          )
        : _ChromePress(
            onPressed: onPressed,
            isInteractive: isInteractive,
            child: Center(child: glyph),
          );

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: button,
    );
  }
}
