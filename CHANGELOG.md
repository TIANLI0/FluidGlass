# Changelog

## 0.1.12

### Performance

- `LiquidBottomTabs` no longer captures its accent-tinted tab copy on every
  frame the selection pill moves. The copy used to be a second glass element
  of its own inside a `BackdropLayer`, and since its lens and rim follow the
  press, the pill re-captured it — an `OffsetLayer.toImageSync`, a pipeline
  flush — on every frame of every tab switch. The pill's backdrop now draws the
  copy's glass itself: the same blur and lens, resolved for the whole bar's
  geometry but run in a save-layer the size of the pill's window onto it, so
  the lens still bends along the bar's edge exactly where it did. The accent
  tab row is still a captured subtree, but nothing in it moves any more — its
  press scale is applied where it is drawn — so it is captured once and read
  every frame. What a tab switch costs is now the panel and the pill, with no
  capture in between.
- The bar's animated values — the pill's position, the panel's give under an
  over-drag, the tab press scale — are read during paint. Nothing in the bar is
  rebuilt or laid out per frame.

### Added

- `BackdropEffectScope.resolve` takes `layerRect`: the window of the padded
  element the filters will actually run over. `BackdropEffectGeometry.layerRect`
  carries it to shader effects, whose `layerSize` and `offset` then describe
  the window rather than the whole layer.
- `BackdropLayer.changeMargin`: how far outside what the glass reads a repaint
  inside the source is still taken to reach it. A change is placed by the box
  of the render object that repainted, and a render object may paint past its
  box, so the default allows 64 logical pixels. An app whose widgets overflow
  less than that can lower it, and a card deck or a list row animating just
  above a glass bar then stops costing the bar a capture on every frame.
- `BackdropDrawContext.quality`: the tier the consuming element draws at, for a
  `Backdrop` that resolves effects of its own.
- `InteractiveHighlight.paintOverlay`, the press glow as a canvas call.
- `LayerBackdrop.source`, the attached source, for a backdrop that draws it in
  the source's own coordinates.

### Changed

- `LiquidBottomTabScale` still marks the accent copy of the tabs, but the scale
  it reports there is now always 1.0 and its notifier never fires: the copy is
  scaled at paint time inside the pill.

## 0.1.10

Three ways a live backdrop now costs less, none of which changes a pixel at
rest. Every capture is an `OffsetLayer.toImageSync` — a rasterisation of the
source that flushes the pipeline mid-frame and scales with the pixels it
covers — and all three are about taking fewer of them, or smaller ones, only
where nobody can see the difference.

### Performance

- **Glass elements reading overlapping strips share one capture a frame.**
  Every region a consumer asks for is remembered for a generation, and a
  request is captured together with any region it overlapped last frame. A
  bottom tab bar and the accent copy its pill magnifies read the same strip
  through paddings that differ by a few pixels, so the first capture never
  quite contained the second request and every frame of a scroll cost two
  captures of almost the same strip; it costs one. Strips that do not overlap
  — a top bar and a bottom bar — are still captured separately, since one
  capture spanning both would cover more pixels than two.

- **A change that lands nowhere under any glass no longer costs a
  re-capture.** The layer watch records where every leaf draws, in the
  source's own coordinates, and reports a change only if a leaf that is new,
  gone or altered lies within 64 logical pixels of something a consumer reads.
  A scroll notification is placed the same way, from the scrollable that sent
  it. A progress spinner, a marquee or a carousel at the top of a page used to
  keep the glass bar at the bottom re-capturing and repainting on every frame;
  for a bar over a page like that the idle cost is now nothing. Leaves are
  matched by signature — the picture's identity hashed with what every
  container above does to it — rather than by position, so a list item
  scrolling into view shifts nothing. A change whose placement cannot be known
  (under a `LeaderLayer`, a `FollowerLayer` or a custom container) is still
  taken to be anywhere.

- **`BackdropLayer.motionPixelRatio`**: a second capture resolution used only
  while the source is *in motion* — re-captured on consecutive frames — with
  one full-resolution capture taken the frame after it stops. A one-off
  repaint never drops. The frames on which the capture is paid every frame are
  also the frames on which a softer capture cannot be seen, and glass that
  blurs what it samples hides the difference outright; at rest, where a soft
  capture would show, the capture is sharp. Leave it null for glass that shows
  the source unblurred and magnified while the source itself moves.

- `RenderBackdropLayer.debugLastCapturePixelRatio` and `debugIgnoredChanges`
  join `debugCaptureCount`, for tests that pin what a frame costs.

### Changed

- `LayerBackdrop.invalidateSource` takes an optional `within` render object,
  for a change confined to one subtree. Without it the change is taken to be
  anywhere, as before.

## 0.1.9

### Added

- `nativeBackdrop`: a backdrop that is whatever the compositor has already
  painted beneath the element, so the whole chain becomes a
  `BackdropFilterLayer` — Flutter's own `BackdropFilter` — with no capture at
  all. The right instrument for a surface that sits *over* what it filters,
  which is most modal chrome: a sheet, a dialog, a selection toolbar, a button
  on a collapsing header.

  It removes three things, not just cost. **The capture:** a full-screen
  `toImageSync` is a texture the size of the screen — 18 MB on a 1440x3168
  phone — allocated and rasterised every time the surface opens. **The
  staleness:** a capture freezes at the moment it was taken, so anything moving
  behind the surface stops moving inside it. **The dim bookkeeping:** a capture
  has to have the modal barrier's dim painted into it by hand or the surface
  reads as a lit window over a dimmed page, while a compositor filter is above
  the barrier already.

  There is a fourth, which is what prompted it: a captured source can *stop
  existing*. A button on a collapsing app bar refracting the header image behind
  it draws nothing once the header collapses away — a transparent hole with the
  page scrolling through it. `nativeBackdrop` filters whatever is behind at that
  moment, which is the header while it is there and the bar's own surface after,
  and is correct in both without the element knowing which.

  An element on it is pinned to `GlassQuality.plain` whatever the device could
  afford — there is no texture for the lens or the shaded rim to bend, so
  sampling would draw nothing. `Backdrop.isCompositorOnly` is the new flag that
  says so, and it outranks an explicit `DrawBackdrop.quality` pin, since pinning
  cannot conjure a texture either.

## 0.1.8

### Changed

- `LiquidSheet.child` is no longer wrapped in a scroll view. `items` still are —
  rows of a known height have an obvious overflow — but free-form content
  usually brings its own scrolling, and nesting two scrollables inside a sheet
  gets you a list that refuses to move. Wrap it yourself if it needs to scroll.

## 0.1.7

### Added

- `LiquidSheet` and `showLiquidSheet`: the half-screen sheet, rounded at the top
  two corners, with a grab handle, an optional title and rows that carry a
  detail line and a trailing check. On a phone this is the form a single choice
  out of several belongs in — rows tall enough to read, a title saying what is
  being chosen — and it was the one common iOS surface the package had no
  component for, so every app rebuilt it by hand on `LiquidPanel`.

  Three things it does that are easy to get wrong by hand: the framework's own
  bottom-sheet surface has to be made transparent so the glass panel is the only
  one, *and its drag handle turned off with it* — that handle paints in the
  surface that just became transparent, so it ends up floating outside the
  glass; `isScrollControlled` has to be set or the framework caps the sheet at
  9/16 of the screen and simply cuts the rows off; and the bottom two corners
  must stay square, since a rounded corner against the screen edge shows a gap.

  The check is at the trailing edge, unlike `LiquidMenuItem`'s leading one: a
  sheet row is wide and its label is what is being read, so a mark at the start
  pushes every label out of alignment with the ones above it. Rows are
  mutually-exclusive selectables to a screen reader, labelled with the detail
  line folded in.

  `surfaceColor` accepts an opaque colour, which drops the glass — what an app
  should pass when it could not capture a backdrop, so the sheet degrades
  without a second layout.

## 0.1.6

### Added

- `LiquidMenu.margin`, `LiquidMenu.rootOverlay`, and a vertical counterpart to
  the horizontal edge avoidance the menu always had. `side` is now the
  *preferred* side: a menu low on the screen asked to open `below` opens `above`
  instead of hanging off the bottom, and `margin` says how close to the
  overlay's edges the panel may come — widen an edge to keep it clear of a safe
  area, or of a bar drawn over the overlay it lives in. When neither side fits
  (a panel taller than the overlay, which flipping cannot rescue) the preference
  is kept, so the result stays predictable.

  `rootOverlay` puts the panel in the root `Overlay` rather than the nearest
  one. The nearest is often a nested navigator's, and anything drawn as that
  navigator's sibling — an app's own bottom bar — paints over it; a menu that
  has to cover such a bar belongs in the root overlay.

## 0.1.5

### Fixed

- A glass element whose paint is harvested as somebody else's backdrop no longer
  takes the native `BackdropFilterLayer` path. That layer filters whatever is
  already beneath it, and `OffsetLayer.toImageSync` rasterises the captured
  subtree on its own — nothing is beneath it there — so the element contributed
  only its plain draws to the picture the capture handed out, and every glass
  element sampling that capture showed the source straight through, unfiltered.

  `LiquidBottomTabs` is where this surfaced. The accent-tinted copy of the tabs
  it captures for the selection pill to magnify drew correctly on screen, so the
  pill was the only thing wrong: a crisp, unfiltered hole in an otherwise
  frosted bar. Only on the cheap tier, which is the one that uses the native
  path — and `GlassDeviceTier` puts every device with fewer than six processors
  there, including the stock Android emulator, so it was easy to hit and easy to
  misread as an integration mistake.

  The condition is read off the ancestor chain when the element attaches, not
  during paint: `alwaysNeedsCompositing` and the backdrop subscription both
  consult the same decision outside paint, and a value that flipped mid-paint
  would leave them disagreeing with what was drawn. Re-parenting detaches and
  re-attaches a render object, so inserting or removing a `BackdropLayer` above
  one is covered.

  `test/bottom_tabs_pill_test.dart` pins each tier in turn and measures the
  luminance spread over black-and-white stripes inside the pill against the same
  band under the panel; before the fix the pill's spread was ~4700 against the
  panel's 0.25.

## 0.1.4

### Added

- `LiquidGlassTheme` and `LiquidGlassColors`, so the components can be drawn in
  an app's own palette. Every component used to inline iOS's values — the blue
  accent, the near-white container tint, the green of a switch — which made them
  unusable in an app whose brand colour is fixed: there was no parameter, and
  re-colouring from outside is not possible, since a `ColorFiltered` over a
  glass element tints the refracted backdrop along with it. The defaults are
  bit-identical to what was inlined and are resolved off the enclosing `Theme`'s
  brightness, so an app that supplies nothing sees no change. Override a field
  or two off `LiquidGlassColors.forBrightness(...)` with `copyWith`; a
  per-element `surfaceColor` still wins over the theme.
- `LiquidButton.height`, `.padding` and `.spacing`. The box was hard-coded to 48
  tall with 16 either side, so the component could not be the 40px circular
  action button that sits on a photo — a size `LiquidSegmentedControl` and
  `LiquidButtonGroup` already exposed. A square button is a circle, since the
  shape is a capsule.

### Changed

- `LiquidButton.onPressed` is nullable, and null disables the button: no
  gestures, no press deformation, no highlight, and no press animation left
  running. The *appearance* stays the caller's — dim the children — and the
  element is inert rather than absorbing, so a tap over a disabled button
  reaches what is behind it, as a disabled control does elsewhere in Flutter.

## 0.1.3

### Added

- The eight liquid-glass widgets that used to live only in the example app are
  now part of the package: `LiquidPanel`, `LiquidButton`, `LiquidButtonGroup`,
  `LiquidMenu`, `LiquidBottomTabs`, `LiquidSegmentedControl`, `LiquidSlider`
  and `LiquidToggle`. They were demo code with no importable path; now they are
  API, with their tests moved into the package's own suite.
- The machinery behind them is exported as well, so a component of your own can
  be built in the same idiom: `SpringValue`, `SpringOffset`, `springOf` and
  `TweenColor` (the Flutter counterparts of Compose's `Animatable` and
  `spring()`), `DampedDragAnimation`, `DragInspector` and
  `InteractiveHighlight`.
- The press-highlight fragment program moved from the example into the package,
  so `FluidGlass.ensureInitialized()` now preloads it with the rest.
- `GlassQuality`, two settings for how much of the liquid-glass look an element
  draws: `liquid` (refraction and a shaded rim) and `plain` (a plain Gaussian
  blur behind the tint, with a flat rim, and no fragment shaders at all).
  Effects read the tier off `BackdropEffectScope` and step aside themselves, so
  no component branches on it.
- `GlassDeviceTier`, which picks the tier from the device once, synchronously,
  before the first frame — so there is no warm-up at the wrong tier and the
  glass never changes appearance mid-session. It reads runtime shader support
  (decisive), whether the process is 32-bit, and the processor count; an unknown
  count or architecture is not held against the device. `describe()` says why.
- `GlassDeviceTier.classifier` replaces that decision with the app's own, for a
  project that has real device information, and `pinnedQuality` bypasses it.
  Both take effect immediately. `GlassQualityScope` pins a tier for a subtree
  and `DrawBackdrop.quality` for one element. All of it is clamped by what the
  backend can draw: without runtime shaders nothing above `plain` is reachable.
- Catalog: a **Quality tiers & device** screen showing both tiers side by side
  with the classification and its evidence, and an **App chrome over a live
  feed** screen — a header and tab bar pinned over a scrolling feed, which is
  the expensive case the rest of the catalog does not cover: the backdrop
  snapshot is invalidated and re-captured every frame of the scroll. It carries
  a `BackdropLayer.pixelRatio` control to show what that lever buys. Plus a
  **Live background** screen for the two live cases that are not a scroll: an
  aurora repainting inside a `RepaintBoundary`, and a photo you pan and pinch,
  with pinned glass over both.

### Changed

- **`GlassQuality.plain` no longer samples the backdrop at all — it hands the
  effect chain to Flutter's own `BackdropFilter`.** Dropping the refraction
  was only ever half a fallback: the lens is a fragment pass over the element's
  own texture, while the capture is an `OffsetLayer.toImageSync` of the whole
  source that flushes the pipeline mid-frame, and for a backdrop that changes
  every frame the capture *is* the cost. So the cheap tier stops sampling: when
  the backdrop is content already painted behind the element, the chain becomes
  one `BackdropFilterLayer` and the engine filters what is behind in place.

  No capture, no pipeline stall, no texture held alive, and nothing to
  invalidate — the frozen-backdrop class of bug cannot occur on this path at
  all. The blur is the engine's own separable, downsampled Gaussian, which is
  the fastest one reachable from Dart; a hand-written blur would have to go
  through `ImageFilter.shader`, a per-pixel fragment program with neither
  separability nor downsampling, and is exactly what this tier exists to avoid.
  Elements on this path also drop their subscription to the `LayerBackdrop`, so
  a source with no other consumer stops capturing itself entirely.

  It cannot replace the liquid tier: a fragment shader inside a backdrop filter
  is handed the whole screen rather than the element's texture, so the lens
  would have no geometry to anchor to. The tier that has given up the shaders
  is exactly the tier that can use it. It also steps aside for anything the
  compositor cannot do — a `CanvasBackdrop` or `WrappedBackdrop`, which the
  element has to draw itself, an `onDrawBackdrop` that transforms the drawing,
  or an `exportedBackdrop` that has to be handed back as a picture — and those
  keep sampling on every tier. Sibling glass inside a `BackdropGroup` shares one
  read of the backdrop rather than each taking its own.

### Fixed

- **A rectangular glass element bled its blur outside itself.** The clip was
  skipped whenever the outline was a rectangle covering the element — true of
  the element, false of what gets drawn, since the backdrop goes into a layer
  inflated by the blur radius so the blur has pixels to reach for. Without the
  clip that layer smeared whatever was behind it for `radius` logical pixels on
  every side.
- **Blur was starved where its source ended.** The capture covers the source
  and no more, so a blur reading past it mixed in transparent black — a dark
  fringe along every edge where glass met the end of its source, which for app
  chrome is the edge of the screen. The capture's outermost row and column are
  now extended outwards, as `TileMode.clamp` would.
- **A `LayerBackdrop` whose source scrolled showed a frozen capture.**
  `RenderBackdropLayer` invalidated its snapshot, and told its consumers to
  repaint, only from inside its own `paint` — which assumes that a source
  repainting means an ancestor repaints. It does not:
  `RenderViewport.isRepaintBoundary` is true, so a list scrolling inside a
  `BackdropLayer` repaints without its ancestors repainting at all. Nothing
  marked the glass over it dirty either, so pinned chrome over a scrolling feed
  kept drawing a stale capture — the backdrop stood still while the content
  moved. Every other case in the catalog puts glass over a still wallpaper,
  where a stale capture is the correct answer, which is why it survived this
  long.

  `BackdropLayer` now watches for scroll notifications bubbling out of its own
  subtree and invalidates on them, and takes an optional `liveness` listenable
  for a source that changes behind some other repaint boundary — a video, a
  `RepaintBoundary`-wrapped animation. Invalidation is deliberately driven by
  those signals rather than by the frame counter: re-capturing every frame
  would be correct and would also undo the point of caching, so glass animating
  over a still source still costs no re-capture. Both halves are covered by
  tests.

- **A background that repainted behind a repaint boundary of its own still
  froze.** Scroll notifications cover a scrolling list; nothing covered a
  `RepaintBoundary`-wrapped animation, a custom painter on its own ticker, a
  Rive or Lottie scene. `markNeedsPaint` stops at the nearest repaint boundary,
  so those repaint while `RenderBackdropLayer` sleeps through it, and the only
  way out was for the app to know about `liveness` and pass it. The captured
  *layers* are now watched instead: a repaint replaces the `ui.Picture` of
  every layer it touches and a retained subtree keeps the same ones, which
  makes a walk of the layer tree an exact answer to "did anything in here
  repaint" — for the price of visiting a few dozen layers on frames that were
  happening anyway. It costs one frame of latency, so `liveness` is still worth
  passing when something already knows; it is no longer required.

  The watch is careful not to duplicate the mechanisms that already work: a
  frame a scroll notification, a `liveness` tick or the source's own repaint
  already accounted for is not re-reported. Pinned glass over a scrolling feed
  still costs exactly one capture per glass strip per frame, which is pinned by
  a test that counts them.

- **Glass over a source that was scaled, rotated or zoomed sampled the wrong
  pixels.** The capture is taken in the source's own coordinates and was placed
  with the offset between the two origins, which is only the whole story while
  both sit under plain translations. Under an `InteractiveViewer`, a
  `FittedBox` or a page mid-transition it is not: the glass refracted a
  wrongly-scaled copy of what it covered. The full transform between consumer
  and source is used now, so glass over a pinched photo magnifies by exactly as
  much as the photo does. That also subsumes the element's own `layerBlock`,
  which used to need a second, separate correction — and it lets an element
  with a `layerBlock` ask for the region it actually reads instead of forcing a
  whole-source capture.

- **A source that only moved left the glass on stale coordinates.** A page
  sliding in or a viewer being panned changes nothing inside the source, so its
  capture stays valid and nothing repaints; what changes is where each consumer
  has to read it. Glass insulated by a repaint boundary of its own never found
  out. The source's own placement is watched now, and consumers are told to
  re-place what they sample *without* the capture being thrown away.

- **Glass inside its own `BackdropLayer` produced a black or garbled backdrop
  and pinned the frame rate.** `BackdropLayer(child: everything)` with the glass
  somewhere in `everything` is the natural thing to write and cannot work: the
  capture is taken while the source is halfway through painting, so its layer
  holds no finished picture yet, and the glass marking itself dirty marks the
  source dirty too — the two then repaint each other every frame, forever. It
  is now detected exactly (the source knows when it is inside its own `paint`),
  reported once with the composition that does work, and stopped rather than
  left spinning.

- A `BackdropLayer` holding a texture or platform view — a video, a camera
  preview, a native map — now says so in debug. Capturing a layer tree does not
  include content the platform draws, so glass over one refracts a hole; that
  was silent before.

- Glass nested inside an element that exports its own backdrop and scales itself
  refracted a wrongly-sized copy of it. `PictureBackdropSource` records where it
  sits as a full transform now rather than as an offset.

- **The cheap tier still ran a fragment program on every press.**
  `GlassQuality.plain` is defined as running none, and the lens and the rim's
  directional shading both honour that; the press glow under a finger did not.
  It was gated only on whether its program had loaded, so a device that gave up
  the refraction to keep its frame budget still paid a shader pass whenever a
  `LiquidButton`, `LiquidBottomTabs` or `LiquidSegmentedControl` was touched. It
  now resolves the tier the same way `DrawBackdrop` does — element pin, then
  `GlassQualityScope`, then `GlassDeviceTier`, clamped by the backend — and
  falls back to the flat brighten it already had for backends without shaders.
  `GlassQuality.hasShaders` names the contract, and a test asserts that no paint
  a plain-tier component makes carries a shader, pressed or not.

- A glass element that scaled and faded at the same time painted its child at
  full size for as long as its `alpha` was below 1. `RenderGlassTransform`
  applied the `GlassLayer` matrix straight to the canvas whenever the subtree
  did not otherwise need compositing, but the fade went through
  `PaintingContext.pushOpacity`, which appends a layer to the enclosing
  *container* layer — and a layer never sees a canvas matrix. The child
  therefore snapped to full size the instant the fade began and snapped back
  when it ended. A `LiquidMenu` blooming out of its anchor flashed twice per
  open/close because of it, at the two moments its alpha crossed 1.0. The
  transform is now promoted to a real layer whenever the fade needs one.
- Catalog: a `LiquidMenu` row stayed live to taps while the panel was animating
  away. The panel stays mounted for the whole closing spring and the dismiss
  barrier steps aside as soon as the close starts, so a tap aimed at whatever
  the menu had been covering selected a row instead.
- Catalog: switching between two `LiquidMenu`s cost two taps — the first was
  spent on the dismiss barrier and the second anchor never saw it. The barrier
  still absorbs the press, so dismissing never doubles as pressing, but it now
  resolves a press on a sibling menu's anchor itself and opens that menu.

## 0.1.2

Roughly 40% off the raster time of an animating glass element, with the
rendered pixels held fixed. Measured on a scripted bottom-tabs drag (Windows,
Impeller, 6 s, three alternating runs against the previous release):
raster mean 5.15–5.46 ms → 3.02–3.09 ms, p90 7.08–8.04 ms → 4.42–4.56 ms,
p99 9.71–11.23 ms → 6.35–6.75 ms.

Every change below was verified by rendering all fifteen catalog screens
before and after and comparing them pixel by pixel. What survives is a maximum
of 6–17 (out of 765, summed across RGB) on a fraction of a percent of pixels,
confined to the soft gradient of a drop shadow.

### Performance

- The drop shadow and inner shadow are baked into cached GPU textures and
  re-baked only when their geometry changes; an animating `alpha` now only
  modulates the cached image. Skia caches blurred masks by path and sigma, so
  redrawing a soft shadow each frame used to be nearly free — Impeller has no
  such cache and ran the full Gaussian every frame. The cache steps aside
  automatically when a key churns (an inner shadow whose radius follows a
  press, say), because re-baking every frame is worse than not caching at all.
- The highlight rim is deliberately **not** baked. It is a hairline, and both
  baking it and dropping its save-layer were measured to shift its pixels.
- The resolved outline and corner radii are memoised per (shape, size, text
  direction). A continuous-curvature outline is twelve cubics solved from
  scratch, and building a fresh `Path` every frame also missed Impeller's
  tessellation cache.
- With no compositing descendant, the shape clip goes straight onto the canvas
  instead of through `PaintingContext.pushClipPath`, which copied the whole
  path engine-side every frame.
- `DrawBackdrop` takes `isolateSurface` (default true). A surface that only
  paints src-over produces identical pixels without the isolating save-layer.
  The isolating layer is also no longer raised for `onDrawBehind` alone, which
  paints under the backdrop where src-over is associative.
- An exported backdrop is only re-recorded when something is sampling it.
- Zero-alpha highlights, shadows and inner shadows are skipped entirely.
- Catalog: the invisible accent copy behind the tab pill is clipped away
  rather than filtered away, which drops an offscreen pass and stops
  `ColorFiltered`'s `alwaysNeedsCompositing` from promoting the glass
  element's shape clip to a compositing layer. Pixel-identical.
- Catalog: flat `CanvasBackdrop`s are cached by colour instead of rebuilt from
  an inline closure each frame, which had made every consumer unsubscribe,
  resubscribe and repaint on every pointer move.
- Catalog: the adaptive-luminance screen no longer restarts a one-second tween
  every second when the measured luminance has not changed, which kept a
  ticker alive on an idle screen.

### Fidelity with the Compose original

- The velocity spring's threshold was 50–500× too large, which made it settle
  on its first tick — so the squash-and-stretch tracked the raw velocity
  tracker with no lag, no overshoot and no ring-down. Compose's live threshold
  is the animation spec's `visibilityThreshold * 10f`; the port had copied the
  `Animatable(0f, 5f)` constructor argument, which Compose only uses to build
  the default spec for calls that do not pass one.
- Presses are no longer cancelled by Flutter's 18 px touch slop. Compose's
  `clickable` has no distance test, so pushing a glass button around under a
  finger and releasing still counts as a press; `TapGestureRecognizer`
  self-rejected instead. Taps now come from the same slop-free inspector that
  drives the press highlight.
- `LiquidBottomTabs` reports a selection only when the index actually changes.
  Compose reports through a `snapshotFlow`, which does not emit on a
  no-op release.
- `DragInspector` now learns when another competitor claims the pointer, via a
  non-competing arena member, so a press releases as soon as an enclosing
  scrollable takes over — Compose sees this as `isConsumed`. It also hands the
  drag to a surviving finger when the tracked one lifts, instead of ending it.
- Fixed the demo's bottom navigation bar border being sheared vertically at
  either end when seen through the dragged pill. The panel-offset translate
  sat inside the accent copy's `BackdropLayer`, and `OffsetLayer.toImageSync`
  clips hard at the layer's bounds — unlike Compose, which records the copy's
  draw commands unclipped — so the give the panel takes on while dragging
  pushed the copy's end cap outside the captured region. The translate now
  sits outside the `BackdropLayer`, so the capture box moves with the panel.
- Zero-alpha highlights, shadows and inner shadows are skipped entirely
  instead of costing a save-layer each.
- The demo's interactive highlight reuses one cached `FragmentShader` instead
  of creating and disposing one per paint.
### New catalog components

- `LiquidPanel` — the glass surface everything else is built from, split out so
  it can be used on its own: vibrancy, blur and refraction over a backdrop, a
  container tint, a rim and a drop shadow. Its `reveal` is read at paint time
  and ramps the refraction depth, rim and shadow together, so an appearing
  panel reads as glass thickening into place rather than a picture fading in.
- `LiquidMenu` — a pop-up menu that blooms out of its anchor as a
  `LiquidPanel`, with screen-edge avoidance, tap-outside dismissal and a
  slop-free row press. The panel lives in the `Overlay` rather than in the
  anchor's own box, because Flutter bounds-checks every ancestor while
  hit-testing and a panel merely drawn outside its parent would render but
  never receive a tap. Two motion details were found by measuring on-device
  and are worth recording: the opening spring must be critically damped (an
  underdamped one bloomed to 102.8% and eased back over ~175 ms, which on an
  opaque panel reads as a *second* opening animation), and the portal must not
  be re-shown while already showing (`OverlayPortalController.show` assigns a
  fresh z-order slot unconditionally, which remounts the overlay child and
  replays the bloom).
- `LiquidButtonGroup` — a capsule holding several actions, for a back cluster,
  a toolbar pair or a Cancel/OK bar. It carries `LiquidButton`'s drag physics
  exactly: the glass follows the finger through a bounded `tanh`, stretches
  along the direction of travel, and springs home on release.
- `LiquidSegmentedControl` — a compact picker whose thumb rides the same
  damped-drag physics as the bottom-tabs pill, over a capsule-shaped
  `LiquidPanel`.

## 0.1.1

- Fixed the demo's bottom navigation bar being visibly sliced at either end
  while dragging. Flutter's `Stack` clips as soon as a positioned child
  overflows, and the selection pill's position lands on the panel's bounds
  exactly at both ends, so rounding decided whether the clip engaged -- and
  when it did it sheared the panel's rounded cap into a straight edge. Every
  `Stack` that stands in for an unclipped Compose `Box` now sets
  `clipBehavior: Clip.none`.
- Added screenshots to the package and the README.
- The capture harness takes `FLUID_GLASS_SHOT_SCALE` for the pixel ratio it
  renders at.

## 0.1.0

First release. A port of
[Kyant0/AndroidLiquidGlass](https://github.com/Kyant0/AndroidLiquidGlass) 2.0.0
and [Kyant0/Shapes](https://github.com/Kyant0/Shapes) 1.2.0 to Flutter.

- `DrawBackdrop` / `DrawBackdrop.plain` glass elements, drawing in order:
  shadow, backdrop, surface, child, highlight, inner shadow.
- Effects: `blur`, `lens` (refraction, depth, chromatic dispersion),
  `colorControls`, `vibrancy`, `opacity`, `colorFilterEffect`, plus
  `imageFilterEffect` and `fragmentShaderEffect` for custom ones.
- Backdrops: `LayerBackdrop` + `BackdropLayer`, `CanvasBackdrop`,
  `CombinedBackdrop`, `WrappedBackdrop`, `emptyBackdrop`, and exported
  backdrops.
- `Highlight` (plain / directional / ambient), `GlassShadow`,
  `GlassInnerShadow`.
- Continuous-curvature shapes: `Rectangle`, `RoundedRectangle`, `Capsule`,
  `UnevenRoundedRectangle`, with `GlassShapeClipper` and `GlassShapeBorder`
  adapters.
- The full Backdrop Catalog demo, all fourteen screens.
