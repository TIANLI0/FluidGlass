# Changelog

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
