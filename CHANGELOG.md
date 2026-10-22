# Changelog

## Unreleased

### Added

- `SoftFloatingNavigationBar.accessoryPlacement`
  (`SoftFloatingAccessoryPlacement`): where an expansion view rests on a
  compact screen. `edge` (the default, unchanged) pins it to the bar's end
  edge. `adjacentCentered` splits it off right beside the capsule,
  `sideSpacing` (12) away; the capsule narrows a little (items capped at
  `itemMaxWidthAdjacent`, 62) and the capsule with the round view is centred
  as one group. `adjacentCapsuleCentered` keeps the capsule's centre where it
  is and hangs the round view off its end, 12 away: the capsule keeps its
  width where the view fits beside it and otherwise narrows just enough,
  about its centre. Both also apply to `start` / `end` round views, which
  then sit beside the capsule symmetrically instead of at the bar's edges.
  Capsule-centred `start` / `end` views melt out of and back into the
  capsule's ends like an expansion does, both at once if need be; the
  capsule reserves room for a side only while its view is out, narrowing and
  widening about its centre. Going out and back in, the capsule's
  position and width follow the same springs as before — no jumps.

## 0.5.1

### Added

- `SoftFloatingAccessory.id`. When it changes while the round view is out,
  or still drawn on its way back in, the view stays where it is and only
  its icon changes: the old icon shrinks to half and fades as the new one
  grows from half, on the springs the view itself comes out on (alpha
  0.35 / no bounce, scale 0.55 / 0.35 bounce). `onTap` and `semanticLabel`
  switch at once. A change back mid-way turns round from where it is; a
  view going in keeps the icon it leaves with. Reduced motion replaces the
  icon outright, and a view without an `id` behaves as before.

### Fixed

- `SoftFloatingNavigationBar`: when the capsule narrows for a round view,
  its items follow the animated width instead of taking the narrowed width
  on the first frame — they no longer jump inwards while the outline has
  not moved yet.
- A bar without a captured backdrop that has round views draws its capsule
  through the merged body even when none is out, so a view coming out or
  the last one going in only changes the traced outline. Swapping the
  capsule's own panel for the merged body built a fresh `BackdropFilter`
  on that frame, and the capsule flashed without its tint.

## 0.5.0

### Added

- The floating bar's round views melt into the capsule without a captured
  backdrop. `SoftMetaBallSurface(compositor: true)` traces the merged
  silhouette into a path (`softMetaBallPath`, the same smooth union the
  shader evaluates), clips the compositor's blur and tint to it and lights
  its edge with the new `soft_meta_ball_edge.frag` — no page capture, no
  `toImageSync`. `SoftFloatingNavigationBar` uses it whenever no
  `backdrop` is given, so an `expansion` shown on one tab now grows out of
  the capsule's end and melts back, with the capsule springing aside.
- `SoftGlass.shape` overrides the rounded-box outline.

### Performance

- A sampling layer whose content has not changed is rasterised once from its
  second unchanged frame and drawn as an image, instead of replaying its
  whole effect chain whenever anything else on the page repaints. Content
  that changes on alternate frames backs off; a repaint an element did not
  ask for no longer counts as a change.

### Fixed

- An `expansion` going back in no longer jumps into the capsule on the first
  frame: it springs from where it rested.
- With reduced motion the round views and the capsule go straight to where
  they end.
- The capsule's move spring settles within 0.02 logical px rather than
  0.001.

## 0.4.0

### Behaviour changes to check when upgrading

- `SoftFloatingNavigationBar` resolves its own taps on lift, by the item the
  finger is over, instead of with a tap recogniser: a press that wanders
  inside its item still clicks it, lifting on another item clicks that one,
  and the gaps between items click nothing. A slide is delivered wherever it
  ends — on a lift outside any item, on a cancelled gesture, and back on the
  item it started from (reported again). A tap on the selected item is only
  reported with the new `dispatchWhenAlreadySelected: true`.
- The bar's box is the capsule with 16 above and below, plus
  `navPad(inset)`: the capsule sits 8 above the system inset, 24 above the
  screen's edge where there is none. `SoftFloatingNavigationBarDefaults.
  extent` is now `88 + navPad(inset)` rather than `88 + inset`. The inset
  falls back to the system gesture inset where the view padding is 0.
- From 600 wide the capsule fills the bar.
- The capsule's blur is the platform's radius-25 blur (sigma ≈ 14.9 physical
  pixels), not a sigma of 25; its edge is a 2.5-wide white line with near and
  far fades (0.25 light, 0.8 dark) instead of the bloom rim, kept on the
  opaque capsule; and a faint caustic light falls below it.

### Added

- Components for common app screens: number and date wheels with a date
  dialog (`SoftNumberPicker`, `SoftDatePicker`, `showSoftDatePicker`),
  `SoftPullToRefresh`, `SoftExpandableList` / `SoftExpandableGroup`, rich
  notification cards with swipe actions (`SoftNotificationSnackBar`,
  `SoftNotificationSwipeBox`), `SoftHorizontalPopupMenu` and a
  native-selection context menu (`SoftTextSelectionMenu`), `SoftSwitch` and
  `SoftGlyphIcon`; next to them, dialogs and the loading dialog, the bottom
  sheet, buttons and chips, the snackbar, top tips, tooltip, progress and
  page indicators, the empty state, text fields and the search bar, popup
  lists and dropdowns, checkbox, radio button and slider, the top app bar,
  tab row and chip tabs. All are exported from the public library.
- `SoftColors.copyWith` covers every palette role;
  `SoftSpotLightParams.copyWith`; `SoftTouchMotionState` exposes the light's
  position, progress and extinguishing state.
- `SoftFloatingNavigationBar`: `expansion` (one round view at the capsule's
  end; while it is out on a compact screen the capsule springs over to the
  start edge to make room), `visible` (fades, shrinks and blurs the capsule
  away), `scrimColor` (a fade behind the capsule that takes no touches),
  `stroke`, `caustic`, `selectedColor` / `unselectedColor`,
  `dispatchWhenAlreadySelected`. Items read as tabs to screen readers.
- `SoftMetaBallSurface.layers` and `.blur`, `paintSoftCapsuleEdge`,
  `paintSoftCaustic`, `SoftBadge.animate`.

### Fixed

- The shadow beside the capsule no longer swallows touches meant for the
  page under the bar.
- Round views melt into the capsule only while they cross its edge: their
  opacity comes from how much of them is under the capsule, a hidden one
  stops taking part in the merged body, and one fully under the capsule
  stops at once instead of bouncing unseen. Without melting (no backdrop, no
  blur, reduced motion) they fade and grow in place on their own springs.
  A round view takes no press until it is all the way out. On a compact
  screen round views are pinned to the bar's edges.
- The merged body uses the bar's own blend-layer material and blur, so the
  capsule looks the same with or without round views.
- `SoftTouchMotion`: a second finger takes the motion over and lifting the
  followed one hands it to a finger still down; the light stays under the
  finger while the surface is moved and scaled; the dead zone is checked on
  every move; a reset while disabled no longer rebuilds the listener during
  its own build.
- The spotlight's extinguish radius spreads by `2 · endRadius`.
- Soft springs no longer stall under continuous pointer updates: a retarget
  keeps the running ticker's clock. Touch transforms are applied at paint
  time, and touch feedback honours reduced motion and ignores secondary
  mouse buttons.
- `SoftPressable`: a press held past half a second still fires on release
  (a long-press recogniser joined the arena even without `onLongPress`), and
  pending feedback is cancelled when it is disabled.
- `SoftTooltip` shows on a long press anywhere on its anchor; `SoftTopTips`
  leaves the tree once closed; popup lists open and close at once under
  reduced motion; the search bar, chip tabs, input view and swipe box no
  longer start their first animation already at its end.

## 0.3.0

### Added

- The soft component family: a solid, flat set of components next to the
  liquid one, themed by `SoftTheme` / `SoftThemeData` (`SoftColors`,
  `SoftTextStyles`).
  - `SoftFloatingNavigationBar`: a frosted 56-high capsule floating 8 above
    the bottom edge. The selected item differs only in colour and icon; the
    whole capsule sinks, follows and stretches under the finger with a light
    that tracks it, and sliding onto another item selects it on the spot,
    lifting there goes to it. Optional round views (`SoftFloatingAccessory`)
    at either side melt into the capsule through one merged silhouette.
  - `SoftBasicComponent` (list row), `SoftCard`, `SoftSmallTitle`,
    `SoftDivider`, `SoftBadge`.
  - Building blocks: `SoftTouchMotion` (area-based sink, rubber-band follow,
    stretch, hand-up rebound), `SoftPressable` (delayed press with a state
    layer or a sink), `SoftGlass` (blur, tint layers and a lit rim),
    `SoftMetaBallSurface`, `SoftSquircleBorder` / `softSquirclePath`,
    `SoftSpring` and the spot-light presets.
- `THIRD_PARTY_NOTICES.md` and `NOTICE` credit the project the soft family is
  ported from.

### Notes

- Tint layers with colour-dodge, overlay or luminosity are blended inside the
  backdrop filter by a fragment shader. Painting them as ordinary paints over
  a `BackdropFilter` blanked the whole frame on Impeller's GLES backend in a
  deeper layer tree.
- 0.2.1 was published by mistake and its change — a selection spring
  separate from the drag's on `LiquidBottomTabs` — was reverted. This release
  follows 0.2.0 and does not contain it.

## 0.2.0

### Behaviour changes to check when upgrading

- `LiquidSlider` reserves a 48-pixel touch target by default; pass
  `touchTargetHeight: 24` for the old layout.
- A disabled `LiquidToggle` (`onSelect: null`) is drawn at 38% opacity. Drop
  any dimming wrapper of your own, or it dims twice.
- Taps on a `LiquidToggle` — knob included — go through the gesture arena and
  win over a tap handler round it. A dummy tap handler added to stop a row from
  flipping the switch a second time is no longer needed.
- Sliders, switches, segmented controls and the tab-bar pill claim sideways
  drags (see Fixed). An empty horizontal-drag `GestureDetector` round them is
  no longer needed, and now only competes with the claim.
- A `LiquidInteraction` with `onTap` or `onLongPress` is a semantics button
  with those actions. A `Semantics` wrapper of your own that adds the same
  actions can go.

### Added

- `LiquidInteraction.onLongPress` and `longPressDuration`: a finger resting on
  a control — or on a member of a `LiquidInteractionGroup` — fires it, the
  light goes out there, and lifting afterwards fires no tap anywhere.
  `onPressedChanged` reports the press as the light shows it, for press
  feedback of the caller's own. `semanticLabel` names the button.
- `LiquidBottomTabs.onTabReselected`: the selected tab tapped again — which the
  selection pill, sitting on it, used to swallow. `LiquidBottomTabs.isAccentCopy`
  tells a tab which of its two renderings it is building.
- `ColorBackdrop`: a solid-colour backdrop compared by colour, for controls on
  a plain surface.
- `LiquidNavigationBar.gap` is public, for layouts that line up with the bar.

### Fixed (this release)

- `LiquidBottomTabs` laid out at zero width — the first frame of an app — no
  longer trips `DrawBackdrop`'s constraint asserts; it holds its height and
  draws nothing until it has a width.
- `showLiquidSheet` keeps a sheet taller than the screen below the status bar
  and the notch.
- A `LiquidInteractionGroup` member removed or disabled under the finger lets
  its press go: its light no longer stays lit, and its long press does not go
  off.

### UI essentials

- Added 15 reusable widgets and `showLiquidToast`: native Form-aware text and
  search inputs; checkbox, typed radio, choice/filter chips; controlled generic
  select and a separate Form-owned select; settings section/row/switch/slider;
  inline notices, progress and empty state. No added package dependency.
- Explicit controlled values, nullable disabled actions, borrowed controller
  and focus ownership, native IME and keyboard behavior. Search supports
  debounce/submit flush and cancels stale pending edits. Select preserves the
  current choice on dismissal and rejects options removed/disabled while open.
- Settings rows share a glass pane, switches expose one activation path, and
  labeled sliders support units and start/end callbacks. Progress animates from
  its current display and rests when settled; decorative motion supports system
  reduced-motion settings. Toasts use ScaffoldMessenger and native actions.
- Added a mist-white/system-blue workspace demo with responsive forms,
  validation/reset, cancellable local save feedback, searchable choices,
  project filters, empty state, dark appearance and large-text coverage.
- Single-child buttons now constrain long labels and treat height as a minimum,
  allowing large text to wrap. Existing ordinary-size and square-button layouts
  remain unchanged; parent constraints still apply.
- Added the UI essentials integration guide, screenshots and regression tests.

### Command center

- Added `LiquidCommand`, `LiquidCommandPaletteLabels`, `LiquidCommandPalette`
  and `showLiquidCommandPalette`: grouped, ranked multi-term search across
  labels, descriptions, categories and keywords; keyboard, touch and screen
  reader activation; lazy result construction; async execution, errors and
  retry; localization and theme overrides.
- The new surface uses one glass shell and a continuous spring-driven selection
  beam. Search results crossfade in a fixed viewport. Modal entry and exit
  share a reversible `LiquidMorph` anchored to the launcher. Compact mode
  preserves input state when keyboard space is limited; reduced motion skips
  decorative animation.
- Added a Fluid studio catalog screen, light/dark/mobile screenshots and focused
  interaction, lifecycle, accessibility and animation regression tests.

### Component usability

- `LiquidButton` accepts `child` as an alternative to `children`, plus a
  tooltip. Buttons, toggles, sliders and segmented controls support keyboard
  focus, visible focus borders and application-owned `FocusNode`s.
- Toggles and buttons activate with Enter/Space; sliders and segmented controls
  support arrows and Home/End, respecting RTL for horizontal keys.
- Toggle, slider and segmented-control actions can be null to disable every
  input method. Toggle track taps work across its full width, and cancelled
  toggle drags no longer commit a choice.
- Sliders default to range 0..1 and visibility threshold 0.001, accept
  `onChangeStart`, `semanticLabel` and `semanticFormatterCallback`, and reserve
  a 48-pixel touch target. Set `touchTargetHeight: 24` for the old layout.
  Snapped values are deduplicated; cancellation does not call `onChangeEnd`.
- Segmented controls validate their selection and dimensions and use a finite
  fallback width inside unconstrained rows.
- Slider, toggle and segmented-control translations run in the render tree
  without building widgets on spring ticks. Untinted buttons skip surface
  isolation, removing an offscreen pass while preserving tinted blending.

### Fixed

- A slider, switch, segmented control or tab-bar pill inside a list keeps a
  sideways drag: the list no longer scrolls under the finger as the drag
  drifts, and no longer cancels the drag halfway. `DragInspector.claimAxis`
  enters the gesture arena for drags along that axis, as Flutter's own
  `Slider` does — whichever axis passes the touch slop first takes the pointer,
  so a vertical swipe that starts on one of them still scrolls the list. The
  claim reads the device's touch slop from `MediaQuery`, as the list does: at
  Flutter's default 18 against an Android list's 8 or so, the list still won a
  drag that went two parts sideways to one part across. The
  events still arrive with no slop, so the controls answer as soon as they are
  touched. Apps that wrapped these controls in an empty horizontal-drag
  `GestureDetector` to get this can drop it.
- `LiquidSlider` reports nothing until the arena gives it the drag
  (`DragInspector.onClaim`): the sideways wobble at the start of a vertical
  swipe over the thumb used to move the caller's value before the list took
  the gesture. On its own, a slider still reports from the first movement.
- A tap on a `LiquidToggle`'s knob flips it once. The knob committed its taps
  from a raw listener the arena never saw, so a switch in a tappable row was
  flipped again by the row and sprang back; every tap on the switch now goes
  through one recogniser that wins over the row's. A knob dragged and let go on
  the side it started from no longer reports its unchanged value.
- `LiquidSearchField` delivers a pending value right after the frame in which
  its debounce changes to zero, instead of on a zero timer that waited for the
  clock to move.
- A glass element fading through its `layerBlock` no longer escapes an
  ancestor's transform or clip. The fade was an `OpacityLayer` even when
  nothing in the element composited, and a layer never sees what an ancestor
  applied straight to the canvas: under a plain `Transform.scale(0.5)` a fading
  element drew at full size, and under a `ClipRect` outside it, for every frame
  its alpha was below one. The fade is now a save-layer on the canvas there.
- `LiquidNavigationBar(isInteractive: false)` fires its actions. The bar
  installs no pointer listener with its motion off, and an action left at its
  own default went on waiting for the bar's finger — a reader who asked for
  reduced motion could not go back. The bar's flag now reaches every island.
- `LiquidToggle` and `LiquidSegmentedControl` stop asking for frames when their
  value changes under a muted ticker. On any route covered by an opaque one the
  settle loop re-armed itself every frame, forever, waiting for a value that a
  muted ticker never moves. The release now waits on the value's own ticks.
- A press is cancelled once the finger leaves the element or a scroll takes it
  over, as Compose's `clickable` is — a finger wandering *inside* the element
  still fires it. Before, lifting fired whatever the finger went down on: a row
  of a scrolling sheet, a button slid off to think better of it, Cancel after
  sliding to OK.
- A child is no longer torn down and rebuilt by a `RimLight` failure shake, a
  press on a navigation-bar island, or a `LiquidButton` being enabled or
  disabled — each switched the widget in one slot between the bare child and a
  wrapper. A sign-in form lost what had been typed on the frame it said "no".
- `GlassShapeBorder` strokes on the side its `strokeAlign` asks for; inside and
  outside were swapped.
- `LiquidFusion` builds its fused body once the fragment programs load, follows
  a device-tier change, and drops to plain under high contrast unless its own
  `quality` is pinned. It chose once, at build, so without
  `FluidGlass.ensureInitialized` a first screen stayed three separate panels
  until something unrelated rebuilt it.
- A component follows a configuration that changes after it was built:
  `LiquidBottomTabs.tabsCount`, a segmented control's segment count and height,
  `LiquidSlider.valueRange`, the backdrop of a toggle or slider, and
  `LiquidAdaptivePanel.interval`. `DampedDragAnimation.valueRange` and
  `pressedScale` are settable for this.
- `LiquidSlider`: a track too short for the thumb no longer throws, a slider
  given no width falls back to a 200-pixel track, an empty range sits at its
  start instead of drawing full, and a reversed range can be dragged.
- `LiquidToggle`: a parent rebuilding mid-drag no longer springs the knob off
  the finger.
- `RimLight` lays its child out as if the light were not there (a tight slot
  used to shrink it), keeps its outline measurements across rebuilds, traces
  start/end corners in right-to-left layouts, and resumes a loading comet when
  reduced motion is turned off again.
- A button disabled under a finger lets its press go; `LiquidInteraction`
  disabled mid-press no longer fires.
- `SpringValue.whenSettled` runs on a snap, a stop or a retarget to where the
  value already is, not only when a spring runs out.
- The Material ink glow no longer shows a hard arc on a control squarer than
  3:2.
- One fragment program failing to load no longer disables every effect, and the
  error reported is the one for the path a consumer asked for.
- Two uses of one shader key in an effect chain each get their own shader, and
  a key reused with a different program gets that program.
- `LiquidMenu` closes on the system back button (and a screen reader's back or
  escape) instead of popping the page underneath it.

### Performance

- Glass no longer rebuilds on every frame of the keyboard sliding in:
  `DrawBackdrop` and `LiquidGlassTheme.of` read `MediaQuery.highContrastOf`
  rather than depending on the whole `MediaQueryData`.
- `LiquidSlider` stops re-capturing its track on every frame of a press: 29
  captures in 30 frames of a thumb held still, 49 for one press, now one or two
  while the thumb grows. The fill repaints only when its width changes.
- `LiquidSegmentedControl` rebuilds three translations per tick instead of the
  panel, every segment and the thumb's glass, and moves the thumb without a
  layout.
- `LiquidAdaptivePanel` stops rasterising and reading back its thumbnail every
  second on a static screen, weights its reading by alpha (transparent capture
  pixels read as black), and rebuilds its content only when the colour flips.
- `LiquidBottomTabs` keeps its accent copy's outlines instead of re-solving the
  continuous-corner paths on every frame of a press or slide.
- `LiquidMorph` no longer repaints its child on every tick under reduced
  motion; `GlassLightField` no longer repaints every receiver when a dark
  source leaves; the fused body's shadow no longer repaints on every rebuild.

### Accessibility

- `LiquidSlider` is a slider to a screen reader: its value and a step either
  way. `LiquidToggle` can be flipped, not only read. Bottom tabs and segments
  are selectable buttons of a set. `LiquidButton` is a button, disabled or not;
  a sheet row can be chosen; `LiquidDialog` names its route by its title; a
  progress `RimLight` reports how far along it is; a disabled navigation action
  says so.
- `LiquidToggle`, `LiquidSlider` and `LiquidSegmentedControl` honour reduced
  motion: a value they move to on their own jumps there.
- `LiquidNavigationBar` places leading and trailing by reading direction.

### Documentation

- `RenderDrawBackdrop.useCompositorLens` and `BackdropLayer.pixelRatio` no
  longer quote synthetic or pre-region-capture numbers as wins; the README's
  live-source section says what the measurements show now.
- `DragInspector.onTap`, the highlight styles' light direction,
  `LiquidMagnifier.size` and the fusion shader's blur taps describe what the
  code does.

## 0.1.31

### Added

- `LiquidBottomTabs.height`: the panel's height, 64 by default as before. The
  tab row and the pill keep their 4dp inset, and a press swells the pill by the
  same proportion at any height.

## 0.1.30

### Added

- `RimLightController` / `RimLight`: light that runs around a control's edge
  as state — focus, loading comet, progress, success sweep, failure pulse.
- `GlassLightScope` / `GlassLightReceiver`: a press lights the glass around
  it, not only the control being pressed. `DrawBackdrop.receivesLight`.
- `LiquidMorph` and `LiquidDialog.morph`: a surface grows out of the control
  that opened it.
- `LiquidGlassColors.glow` and `.success`; the fusion shader takes the glow
  colour.
- `LiquidBottomTabs.isInteractive`: with motion reduced the pill jumps to a
  tab instead of springing, nothing swells under a press and the pill does not
  drag; taps are unchanged.

### Fixed

- `LiquidBottomTabs`: a pressed selection pill no longer shows a white bar
  across its bottom, a grey ghost of the tab label, or a pale band inside its
  inner frame. Three causes, none of them in the look itself:
  - the pill's backdrop was only as opaque as the page capture, which is
    transparent wherever a page leaves its background to the scaffold, so the
    bar under the pill showed through — the page is now laid on the scaffold
    colour first;
  - the accent copy's lens was told its texture was the pill's whole window
    while the save-layer was cut back to the tab row the copy is clipped to,
    so pressed it bent a 56-tall texture as if it were 100 and folded part of
    the page over on itself inside the frame — the lens now gets the region
    it really has, while the blur keeps the whole window (given only the row
    it ran out of pixels at the row's edges and left the page almost sharp
    along the pill's top and bottom);
  - the copy was only redrawn when the page or the tab row changed, so during
    a press it stayed at some earlier progress under a pill still scaling on
    its layer — it now redraws on every frame of the press, as the Compose
    original does.
- The rim light's travelling comet is one continuous stroke whose brightness
  comes from a sweep gradient, instead of ten stepped pieces under two blurred
  blooms. Moving, the seams between the pieces crawled along the edge — round
  caps adding up into beads, the halo changing width in steps — and the comet
  read as a smeared mosaic rather than a light.
- `LiquidSlider` with `divisions` can be dragged in small steps. Each drag
  delta was added to the snapped value the parent echoed back, so a slow drag
  never left its step.
- A fused body always ends up with the room around its shapes, and is never
  cut. The limit was only reported once two consecutive paints agreed
  (0.1.28), which never happens for a body painted exactly once at rest: a
  static page kept the body's own box as its limit (shadow cut off square,
  press swell into a hard edge), and a page that slid in inside a transition
  snapshot kept the limit measured while it was still off-screen, cutting the
  body with a straight edge and dropping the shape at its far end. Now the
  first limit is reported at once, a changed one is re-measured after 100 ms
  without change, and no limit is ever applied tighter than the body's own
  box.
- A fused body stays inside any clip around it, not only inside the screen.
  A layer cut short by a clip hands the shader a smaller texture than the
  element it was told about, and the body came out shifted off its content.

### Documentation

- `LiquidFusion.backdrop` is not `emptyBackdrop`: the whole body is the
  shader's output over the pixels it is handed, so filtering nothing draws
  nothing. Over a flat page, pass a `CanvasBackdrop` filled with the page
  colour.

## 0.1.29

### Added

- `ProgressiveBlur.backdrop`: share a page's existing source and render every
  blur level with native Gaussian filters and native gradient masks, without
  runtime shader image filters. Masks stay in logical coordinates under route
  scaling, opacity and whole-page snapshots. The source must exclude the blur.

### Fixed

- Compositor progressive-blur bands own separate fragment shaders instead of
  mutating one global instance before Flutter materializes their filters.
- Progressive blur rebuilds when its shader programs finish loading, avoiding
  a hard-edged fallback that persists until an unrelated rebuild.

### Validation

- Pixel regression tests cover a sampled source under scale and opacity.
- CouCou's profile-mode route/Android predictive-back probe was exercised on
  a OnePlus PKJ110 with Impeller Vulkan; the app pairs the sampled path with
  complete-page transition snapshots to avoid recomputing blur each frame.

## 0.1.28

### Changed

- A fused body reports its screen limit only once the limit has stopped
  changing, rather than on every frame it changes. Every report costs a rebuild
  of the whole body — the layout callback, the shapes, the shader's uniforms —
  and the limit is different on every frame of a page transition, which is the
  one time the frame budget is already spent. Two paints have to agree before
  anything is reported; any decelerating curve ends with frames closer together
  than the half-pixel tolerance, so the report still lands at the end of the
  transition, and a body that is standing still reports nothing at all.

## 0.1.27

### Fixed

- A fused body no longer keeps a screen limit measured while its page was
  still sliding in. The limit — the screen, in the body's own coordinates — is
  what stops the element growing past the edge of the display, where its layer
  would be clipped and the shader's mapping would go with it. It was worked out
  once, inside the layout callback, and **a page's paint transform changes
  without anything inside that page being laid out or built again**: a route
  slides the whole thing across with one `Transform`. A bar measured on a frame
  where its page was still 79 logical pixels off-screen therefore kept a limit
  79 pixels short for the life of that page — the body ended in a straight
  vertical cut through whichever island happened to be there, and any island
  further out was not drawn at all. Cold-starting onto the same page drew it
  perfectly, which is what made it look like a shader problem rather than a
  geometry one.

  The transform is now read in `paint`, which is what a moving page does every
  frame; a change is reported after the frame and the body rebuilds with the
  new limit. A body that is standing still reports nothing and rebuilds never.
  `example/lib/probe_navigation_bar.dart` has a **push** button for this: the
  bug only ever showed on a page you navigated to.

## 0.1.26

### Fixed

- The ink glow really does last as long as the finger now. Two things cut it
  short. The pointer tracker registers its global route on first use, so the
  first gesture of a session had no down event to claim and fell straight
  through to Material's cancel — the first thing anybody pressed was the one
  control whose light blinked. And the feature disposed itself from inside its
  own spring's `notifyListeners`, which `ChangeNotifier` asserts on, taking the
  glow with it. A gesture with no claim now adopts its finger from the first
  move, and the disposal waits for a microtask. `test/ink_highlight_hold_test.dart`
  holds a finger down for three seconds, drags it past the slop and watches the
  glow stay — the assertions that were missing when this was first written.
- The scroll that puts a glow out is a real scroll. The control was allowed to
  drift one pixel under a held finger before the press was abandoned, and a
  page still finishing its entrance, a list settling out of a fling or a
  keyboard sliding in all move a control by more than that. The threshold is
  now 12 logical pixels, which no amount of settling reaches and every scroll
  passes within a frame or two.
- A fused body no longer re-runs its layout callback every frame for the life
  of any page that sits under a transform. 0.1.25 asked for a rebuild whenever
  an ancestor's scale was not exactly 1, to keep the screen limit fresh through
  a transition. It does not need to: that limit only ever errs *large* when it
  is stale — a page caught mid-zoom at 0.8 maps the screen to 1.25 screens of
  its own coordinates — and a limit that is too large clamps nothing.

## 0.1.25

### Changed

- `LiquidInkHighlight` now behaves like the glow on a liquid control rather
  than like a Material ripple: it comes on with the finger, **stays as long as
  the finger does**, and **follows it** across the control. Material only
  tells an ink feature where the pointer went down and when the tap confirmed
  or cancelled — and it cancels the moment the finger drifts past the touch
  slop, which is why a stock ripple dies under a finger that so much as
  wobbles. The feature now watches the pointer itself through the gesture
  binding's global route and lets go only when the finger lifts, or when the
  control starts moving under the finger (a list being scrolled). The wash and
  the radial glow keep the caller's ink colour, so it reads on a pale page
  where an additive white glow would not.

### Fixed

- A fused body no longer freezes cut short after a page transition. Its
  screen limit was built from `localToGlobal(Offset.zero)` and the screen's
  size, two numbers in different spaces whenever an ancestor scales; a page
  drawn at 0.8× mid-transition had its element clipped at 80% of its width — a
  straight vertical cut through the title island and no trailing island at
  all — and nothing rebuilt once the transition settled, so the cut stayed.
  The screen is now mapped into the body's coordinates through the full
  inverse transform, and the body asks for another frame while an ancestor is
  still scaling.

## 0.1.24

### Changed

- **A press travels across a navigation bar, and so does the tap.** Each
  island used to run its own slop-free tap: press the back button, slide onto
  the title, lift — and the light had crossed the body while nothing fired,
  because only the island that saw the down could. The bar now owns the one
  finger: the island under it lights up and leans, sliding onto a neighbour
  moves the light and the press to that neighbour, and lifting fires whichever
  island the finger is on by then. Lifting in a gap fires nothing. The islands
  stay opaque hit targets, so a tap on one still never reaches the content it
  is drawn over. A body of glass that carries a press from one island to the
  next has to carry the commit with it, or the light is lying about what the
  finger can do.
- `ProgressiveBlur` is rebuilt as a stack of the engine's own Gaussian blurs
  rather than one shader with a per-fragment radius. That shader sampled a
  fixed number of taps whatever the radius: a 24-pixel radius on a 4× display
  is a sigma of ~56 device pixels, 25 taps across it are 6 pixels apart, and
  the result was not a blur but the content copied several times at small
  offsets — a ghost, on every device where the effect mattered. Now each
  `bands` band adds just enough sigma to reach a geometrically growing target,
  every band is the engine's downsampled Gaussian (which never undersamples),
  and a one-sample shader inside each band's chain fades its input along a
  ramp before the blur so the bands slope into each other instead of stepping.
  A third of the samples, no aliasing, and a hard-edged fallback without
  runtime shaders instead of a uniform slab.
- An island answers a finger whether or not it does anything. The title island
  took a press only when `onTitlePressed` made it a button, so a bar whose two
  ends squashed and glowed under a finger had a dead middle — which reads as a
  bug rather than as restraint. It now deforms and carries the light in every
  case; with no callback nothing is claimed and nothing fires.

### Fixed

- `LiquidNavigationBar` no longer paints a black slab when handed a fully
  transparent `scrimColor`. The scrim ramp was built with `withValues(alpha:
  0.94)` on the colour as given, and `Colors.transparent` is black at alpha 0
  — so an app that had moved the scrim elsewhere (a progressive blur under the
  bar) got 94% black darkening towards the islands' bottom edge, and nothing
  threw. The ramp's alphas now scale the caller's alpha, and zero draws
  nothing.
- A fused body and a `ProgressiveBlur` both measure again after a page
  transition. Both bail out of `localToGlobal` while an ancestor is still
  awaiting layout — the route's transform on the frame a page first appears —
  and neither had a reason to try again once the page settled: the body kept
  the box-only geometry it fell back to, which on a navigation bar showed as
  the islands vanishing after every push while a cold start on the same page
  drew them. Each now asks for one more go on the next frame until the
  measurement succeeds.
- A navigation bar's title island can grow past `titleMinWidth`. The island's
  rectangle was computed from the width its content reported, and the content
  reported the width it had been *given* — a fixed point: an island handed 144
  laid out in 144, reported 144, and was handed 144 again. A long title was
  ellipsised to the minimum for ever, and a `titleMinWidth` of zero collapsed
  the island out of existence entirely. It now reports the width its content
  wants, which the bar still clamps to the room between the side actions.
- A fused body no longer throws while a page transition is starting.
  `LiquidFusion` works out how much room it has on screen from inside a layout
  callback, and it asked `localToGlobal` for where it sits. That walks the
  ancestor chain collecting paint transforms, and a transform that scales or
  translates about its own centre has to read its own size to answer — which
  asserts `hasSize` while it is still awaiting layout, exactly what a route's
  transform is on the frame its page first appears. Where the body sits is not
  knowable on such a frame, so it now falls back to its own box and loses only
  the headroom outside it, for one frame, mid-transition. The assert reached
  any app whose chrome is a fused body: navigating back threw a framework
  error every time.

### Added

- `ProgressiveBlur` — a blur that grows from nothing at one edge to
  `maxBlurRadius` at the other, so chrome dissolves into the content under it
  instead of ending on a line: the effect Apple's own chrome gets from its
  private `variableBlur` filter, with the same `startOffset` that holds the
  blurred end at full radius before the ramp begins. Built as a stack of the
  engine's Gaussian blurs with shader-faded seams (see *Changed*), so it never
  undersamples and costs a handful of downsampled blur passes.

  Neither construction people reach for first can do this, and neither throws.
  Fading a full-strength `BackdropFilter` behind a gradient `ShaderMask` fades
  that layer's *opacity*, so the middle of the ramp shows half a blurred image
  over half a sharp one — a double exposure that separates further the harder
  the blur. And a `BackdropFilter` nested in a `ShaderMask` filters that
  mask's own empty save layer rather than the scene, which draws as a dark
  rectangle. Mixing only ever happens here between two images blurred by
  similar amounts, which is what a double exposure cannot survive.
- `LiquidInteractionGroup` and `LiquidInteraction.onTap` — one finger, many
  controls. Every `LiquidInteraction` under the group is a member: the one
  under the finger lights up and follows it, sliding onto a neighbour moves the
  light and the press, and lifting fires the `onTap` of whichever member the
  finger is on by then. A scroll of the list the members sit in cancels the
  press, since the group observes the pointer without claiming it. Outside a
  group, `onTap` makes a `LiquidInteraction` a slop-free control of its own,
  firing on a lift inside its bounds however far the finger wandered — the
  glow having stayed and followed the whole way, unlike a Material ink, which
  dies at the first 18 pixels of travel.
- `LiquidNavigationBar.blurRadius` — how hard the chrome blurs what it sits
  over, which until now was the fixed `chromeBlur` of 8. It is the dial to
  reach for first when chrome does not read against a particular app's
  content: legibility comes from the blur under the glass, not the paint over
  it, so widening the sample costs a wider read where raising the tint's alpha
  costs the glass itself. A bar over running text wants more of it than a bar
  over photographs does.
- `LiquidNavigationBar.titleAlignment` and `titlePadding`. A title that names a
  page belongs in the middle of its island; an identity does not. An avatar and
  a name read as one object starting at the same edge, and dropping the leading
  inset to zero lets an avatar of exactly the island's height share its circle
  with the island's own rounded cap, rather than floating inside it.
- `LiquidNavigationBar.isInteractive` and `LiquidNavigationAction.isInteractive`,
  the flag `LiquidButton` already had. An island's press was unconditional, so
  an app honouring a platform's reduced-motion setting could turn off the
  deformation everywhere except its own chrome. False keeps the tap and drops
  the squash, the lean and the glow the fused body carries.

## 0.1.23

### Added

- `LiquidFusion` — several shapes drawn as one body of glass. The silhouette is
  a field rather than an outline: each shape contributes a signed distance, the
  shader takes their smooth minimum, and the result bulges towards its
  neighbour before the two touch, grows a concave neck, and swallows it.
  `smoothing` is how far apart that reaching starts, and its default of 10 is
  measured — a fused field closes over a gap of about half the smoothing, which
  leaves a row of controls eight apart reading as a row until something moves.
  It is also one glass element for the group: one capture of the backdrop and
  one shader pass where each shape apart pays for its own. `LiquidBlob` is a
  shape, `LiquidFusionPress` is the press the body is under, and the new
  `shaders/fusion.frag` draws all of it.
- `LiquidNavigationBar` and `LiquidNavigationAction` — top chrome as three
  islands of glass over a scrim of the page colour, drawn as one fused body.
  Islands only cover what they hold, so content keeps scrolling visibly between
  them; the scrim is opaque behind the status bar and gone below them, so the
  gaps never read as holes. The geometry is computed from the bar's own layout
  rather than measured off the widgets in it, which is what keeps the glass
  from lagging the icons on it by a frame.
- `LiquidInteraction` — the finger-following press feedback the liquid
  components use, for a control that is not made of glass. It observes pointers
  without claiming their gestures. `activePosition` lets a parent that owns the
  gesture say where the finger is, which is what a menu does for its rows.
- `LiquidInkHighlight` — a splash factory, so every Material ink control in an
  app gets the same soft press glow without being wrapped.
- `InteractiveHighlight.glowPosition`, for something other than the element
  itself drawing its glow.

### Changed

- A menu now tracks a drag across its rows: press the anchor and slide, and the
  row under the finger is the one that commits on release. Releasing outside a
  row cancels, and a cancelled gesture never commits.
- A segmented control's drag can start on any segment, and a cancelled drag
  restores the selection it started from rather than leaving the thumb where
  the finger left it.

### Fixed

- A menu row's press glow no longer sits in the middle of the row whatever the
  finger is doing. The row is activated by the menu, not by its own pointer, so
  it had no pointer to follow; the menu now hands it the one it is already
  tracking.

## 0.1.22

### Fixed

- A pressed toggle no longer exposes rectangular capture edges inside its
  glass knob. `WrappedBackdrop` now inverse-maps the requested sampling bounds
  through its canvas transform before `LayerBackdrop` crops the source. This
  preserves Kyant's original track scaling and lens parameters, including the
  collapsed track at rest, and also works for nested wrappers.

## 0.1.21

### Added

- `LayerBackdrop.extendEdges` — whether the capture's outermost row and column
  are stretched outwards when an effect reads past them. True, the default, is
  right for a source that *fills its bounds*: a page, a wallpaper, a feed,
  where a blur reading past the capture would otherwise mix in transparency and
  leave a dark fringe. Pass false for a source whose content is **not** its
  bounds.

### Fixed

- The toggle's knob no longer shows a square edge on a shape that has none. Its
  track is a capsule inside a 64x28 box, so the capture's outermost column
  holds one coloured pixel at the capsule's widest point with transparency
  above and below it; stretching that column outwards drew the pixel as a
  straight band, and the knob — a round lens looking straight into it — showed
  the band. The track now captures with `extendEdges: false`.
- Reverts 0.1.20's change to the same knob, which addressed the symptom from
  the wrong end.

## 0.1.20

### Fixed

- The toggle's knob no longer shows a square through a round piece of glass.
  It refracts a copy of its own track, and that copy was squashed to 0.75 at
  full press — which pulls the copy's straight ends *into* the knob's view. The
  slider's thumb has always drawn its copy at full size for exactly this
  reason; the toggle now matches it.

## 0.1.19

### Added

- `LiquidSheet.plain` and `LiquidSheet.blurSigma` — drops the glass and blurs
  with Flutter's own `BackdropFilter` instead, keeping the handle, title, rows
  and selection mark. The rim, lens and shadow are what make a *small* element
  read as a bead of glass; a half-screen sheet carrying rows of text needs a
  heavy tint for those rows to stay readable over whatever it covers, and
  behind such a tint there is nothing left for a lens to bend — the rim is then
  the only glass still visible, a bright seam along the top edge that reads as
  a misplaced highlight rather than as material.

### Fixed

- The bottom tabs' selection pill no longer fills with white at full press. The
  captured accent copy painted the press glow a third time — after the bar's
  own and the pill's own — and that copy is *what the lens magnifies*, so the
  glow was blown up with it and the blurred page the rest of the bar shows
  vanished from under the pill.
- The toggle's knob and the slider's thumb no longer square off their sampling.
  Both refract a scaled copy of their own track, which does not fill the
  element's layer; a clamped blur that starts the chain is given no extra room
  — the right call when the layer is full of the thing being blurred, wrong
  here, because it clamps against the layer's straight edges. The bottom-tabs
  pill already raised its padding for the same reason.

## 0.1.18

### Added

- `LiquidSegmentedControl.thumbColor` — the wash painted over the thumb's
  refraction. It has always been white, which reads as *raised* on the grey
  track iOS gives these controls; on a palette whose panel is already near
  white, the thumb had nothing to separate it from the track and the control
  said nothing about which segment was selected — the one thing it exists to
  say. Null keeps the old white exactly, down to the alphas, so nothing that
  does not pass the parameter changes.
- `LiquidSlider.divisions` — snaps the *reported* value to equal steps while
  the thumb keeps sliding continuously under the finger. A device volume of
  0–16 on a finger-width track resolves to about three pixels a step, and a
  continuous slider makes an exact setting a matter of luck.
- `LiquidSlider.onChangeEnd` — fires once when the interaction ends (the
  finger lifts after a drag, or a tap on the track lands). `onValueChanged`
  fires continuously while dragging, so a caller that debounces its writes had
  no way to know the user had stopped, and had to either wait out the debounce
  window after the finger was already gone or write on every frame.

## 0.1.17

### Fixed

- A live backdrop no longer freezes while an Android overscroll springs back.
  On every Impeller backend Flutter's `StretchEffect` stretches with
  `ImageFilter.shader`, and a fragment shader reads the size of the texture the
  pass rasterised it into. Capturing one strip of the source — which is what
  "capture only what is read" has done since 0.1.14 — evaluated that shader
  against the strip's extent, so a bar pinned over a list showed a page
  stretched by some other amount for the whole spring-back. A shader filter
  found in the captured layer tree now takes the whole source for that
  generation; a blur, a matrix or a dilate still take a strip, since Impeller
  can invert those to work out what they read. The cost is paid only on the
  frames such a filter is actually on screen, which for an overscroll is the
  overscroll. `flutter_test` runs on Skia, where `StretchEffect` falls back to
  a plain `Transform` and `ImageFilter.shader` cannot be constructed at all,
  which is why every widget test passed throughout; the end-to-end measurement
  is `example/lib/probe_stretch_capture.dart`.
- `LiquidBottomTabs`' selection pill no longer wears a ring of half-blurred,
  darkened backdrop. The pill declared only `lens(...)` as its effect, and
  `lens` lowers the sampled margin rather than raising it, so the element
  sampled exactly its own bounds — while its backdrop blurs the page by 8
  logical pixels *inside* that layer. The blur ran out of pixels at the
  border. It is most visible at rest, when the pill's own refraction is off and
  nothing covers for it. Measured over hard stripes on Impeller, the surviving
  unblurred contrast in the ring dropped from 69/255 to a flat 18, which is the
  capsule's own anti-aliased edge.

## 0.1.16

### Added

- `LiquidDialog.titleStyle`, `.messageStyle` and `.actionStyle`, merged over the
  built-in type. An app whose design system owns its typeface can re-letter the
  dialog by passing a `fontFamily` alone: the fields left null keep the sizes
  and weights, so the layout does not move.

## 0.1.15

### Added

- `LiquidDialog` and `showLiquidDialog`: a centred modal panel — title, message
  or free-form content, and the actions that answer it. It defaults to
  `nativeBackdrop`, which is what a dialog usually wants: it sits *over* what it
  filters, so the compositor does the work with no capture, and the barrier's
  dim comes free. Pass a `LayerBackdrop` for the refraction instead — with the
  dim inside what that layer captures, or the dialog reads as a lit window over
  a darkened page. Actions never dismiss on their own: a dialog's actions do not
  all end it (one may open a policy to read first), so `onPressed` owns that.
  Up to two actions share a row, three or more stack, and the axis can be
  forced either way.
- `LiquidMagnifier`: a loupe. The magnification is *where the glass samples
  from*, not an effect over it — the backdrop is drawn through a scaled canvas
  before the lens runs, so the rim refracts already-magnified pixels instead of
  framing a picture-in-picture. `focalOffset` says what it looks at relative to
  where it sits, so a text loupe can float above the finger.
- `LiquidAdaptivePanel` and `BackdropLuminance`: glass that measures the average
  luminance of what it sits on and retunes its brightness, contrast and blur to
  stay legible over it, handing the caller the content colour that reading can
  carry. The sampler records one small thumbnail per *sample* rather than per
  frame, and reads it back on a cancellable timer.
- `LiquidPanel.depthEffect`, which blends the edge normal towards a radial one.
  Worth it on a large panel a reader looks straight at; too subtle to tell apart
  on a bar, so it stays off by default.

### Changed

- The catalog's dialog, magnifier and adaptive-luminance pages now use the
  components above instead of hand-rolling them over `DrawBackdrop`. The dialog
  page also shows the modal route, so both backdrops a dialog can have are on
  screen next to each other.

## 0.1.14

### Performance

- Sampled glass records its pixels during composition rather than during
  paint. A glass element used to redraw its whole stack — capture, blur, lens,
  highlight — whenever anything told it its backdrop had changed, and it could
  only be told once the frame that changed it had been drawn, so it also ran a
  frame late. The element now keeps a composited layer that re-records only
  when what it samples actually differs: the source's capture generation, or
  where the element sits. Two things follow. A source that repaints behind a
  repaint boundary is picked up in the *same* frame instead of the next one, so
  `liveness` is no longer what closes that gap — it is left for custom
  rendering state that changes without replacing a picture or a layer property,
  and for glass that sits inside a captured source. And glass that is merely
  marked dirty — by a sibling repainting, by an ancestor rebuilding — reuses
  the pixels it already has.

- Captures follow the regions consumers actually read, rather than one
  rectangle drawn around all of them. A header and a footer over the same
  source no longer force capturing everything between them: their requests stay
  disjoint, both for choosing what to capture and for deciding whether a change
  in the source is one the glass can see. Passing the region budget now takes
  the combined envelope of the outstanding requests instead of the whole
  source, and the choice is remembered so the next generation starts from one
  image.

- Glass that moves or grows across its source latches to a single whole-source
  capture instead of paying a second `toImageSync` every frame. The envelope
  predicted for a consumer comes from the previous generation's requests, so a
  moving consumer outruns it, misses, and captures again — every frame, for as
  long as the motion lasts. A miss that *overlaps* what is already held is now
  read as exactly that, while a miss disjoint from everything held still keeps
  its own small capture.

### Fixed

- The layer fingerprint — what notices a source changing behind a repaint
  boundary — was blind to several kinds of change, and glass over them kept
  drawing a frozen backdrop: an animating `ImageFilter` (which is what
  `ImageFiltered`, and a `Transform` given a `filterQuality`, become — Android's
  overscroll stretch is built from both), a `ShaderMask`, a `ClipPath` or a
  clip behaviour that changes, a `CompositedTransformFollower` moving, and a
  `BackdropFilter` inside the source. A `BackdropFilter` also reads pixels from
  outside its children's bounds, so while one is present a change is never
  dismissed for landing where no consumer reads.

- Leaves are compared in order, so two retained layers swapping stacking order
  counts as a change.

- A change that lands outside every sampled region no longer leaves a wider
  capture behind it. Held images covering the changed area are retired, so a
  consumer that moves into that area later cannot draw stale pixels out of one.

- The baked decoration cache rebuilt its image after a single repeated key once
  it had started thrashing, instead of waiting out the window it uses to decide
  the key has settled. A decoration alternating between two keys paid a
  `toImageSync` every other frame rather than none.

## 0.1.13

### Added

- `LiquidPressDeformation`: the displacement law the pressable components move
  by — the swell while an element is held, the `tanh`-bounded lean towards the
  finger, the stretch along the axis being pulled — as four plain numbers, with
  a `transform` matrix for a `Transform` aligned to the centre. `LiquidButton`
  and `LiquidButtonGroup` resolve it and write it onto their glass layer; it is
  public so that something which is not made of glass can move by exactly the
  same law rather than by a copy of it that drifts. Nothing about the glass
  components' motion changes: the internal `applyDragDeformation` is now the
  one caller that writes those numbers onto a `GlassLayer`.

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
