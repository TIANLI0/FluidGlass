# FluidGlass component library — design

How the existing light field and motion primitives extend to a complete client
component set, and the rules that keep that set coherent and cheap.

This is a design, not a changelog: components marked **new** do not exist yet.
Everything marked ✓ ships today and is listed because the new work has to fit
around it, not because it needs rewriting.

---

## 1. The problem with growing the current set

Seventeen components ship today. Between them they use exactly two glass
recipes, both hand-written at each call site:

| where | recipe |
| --- | --- |
| `liquid_button.dart:140`, `liquid_button_group.dart:77` | `vibrancy() + blur(2) + lens(12, 24)` |
| `liquid_panel.dart:87`, `liquid_bottom_tabs.dart:324` | `vibrancy() + blur(8) + lens(24, 24)` |

Plus animated variants that interpolate those same numbers against a spring —
`liquid_toggle.dart:166` (`blur(8 * (1 - progress))`), `liquid_slider.dart:299`,
`liquid_bottom_tabs.dart:597` (`lens(24 * progress, 24 * progress)`).

Two recipes copied into seven files is survivable. Forty components written the
same way is not: every new control becomes a fresh guess at a blur radius, and
the set stops reading as one material. **The first move is therefore not a
component — it is to name what those two recipes actually are.**

---

## 2. The light field as a system

### 2.1 Depth is the one token

The two recipes are not "thin glass" and "thick glass". They are two heights
above the page. Glass thickness, blur reach and lens depth are all consequences
of one number, and the library should expose that number rather than its three
consequences.

| tier | name | what sits here | blur | lens | tint |
| --- | --- | --- | --- | --- | --- |
| 0 | `flush` | dividers, labels, inline text | — | — | — |
| 1 | `control` | things a finger touches, resting on a surface | 2 | (12, 24) | light |
| 2 | `surface` | bars, cards, panels the page scrolls under | 8 | (24, 24) | light |
| 3 | `overlay` | sheets, dialogs, menus over a dimmed page | 8–16 | none | heavy |

Tier 3 has **no lens on purpose**: it runs on `nativeBackdrop`, which
`NativeBackdrop`'s own doc documents as giving up refraction because there is no
texture to bend. That is not a limitation to route around — a surface carrying
enough tint to make body text legible was never going to show refraction
anyway.

Two rules follow, and they are what stop the set from turning to soup:

- **No tier touches itself.** Two tier-1 controls side by side either fuse into
  one body (`LiquidFusion`) or one of them is not glass. Glass over glass reads
  as dirt, and it doubles the cost.
- **A tier is a claim about elevation, not emphasis.** A destructive button is
  not "thicker glass"; it is tier 1 with `colors.destructive`. Emphasis lives
  in colour and motion, never in blur radius.

### 2.2 Shape and concentricity

The shape vocabulary is fixed and already complete: `Rectangle`,
`RoundedRectangle`, `Capsule`, `UnevenRoundedRectangle`, all defaulting to
`RoundedCornerStyle.continuous` (the G2 squircle from the Kyant0/Shapes port).

One rule governs nesting, and it is the thing that most often looks subtly
wrong when it is missing:

> **Concentric corners.** A child's corner radius is the parent's minus the gap
> between them. A 12 px inset inside a 28 px panel gets a 16 px radius, not 12.

Controls default to `Capsule`. Surfaces default to `RoundedRectangle`. A
surface that meets a screen edge uses `UnevenRoundedRectangle` so the edge stays
square — a rounded corner against the bezel reads as a mistake.

And a second rule that follows from the first, and is easy to miss:

> **A surface flush to the screen edge draws no rim.** A rim traces the whole
> outline, so on a sheet — three of whose four sides are against the screen —
> it puts a bright seam down both bezels and a hard bright point where its
> square bottom corners meet the device's rounded ones. The phone's own corner
> radius is not knowable from Flutter, so there is no radius that would make
> those corners agree. The drop shadow does the separating instead, on the one
> edge the reader can actually see.

This governs `LiquidSheet` (fixed), and applies as written to the new
`LiquidTopBar`, `LiquidBanner`, `LiquidSideRail` and `LiquidDrawer`, all of
which are flush to at least one edge.

### 2.3 Colour

`LiquidGlassColors` already carries the whole palette: `accent`,
`toggleAccent`, `container`, `content`, `track`, `destructive`. New components
take colours from `LiquidGlassTheme.of(context)` and expose a single override,
following `LiquidPanel.surfaceColor`. **No new component invents a colour
slot** — if one seems to need it, the palette is wrong, not the component.

### 2.4 Motion

Motion is spring-described, never duration-described. `springOf(dampingRatio,
stiffness)` plus `SpringValue` / `SpringOffset` / `TweenColor` are the whole
vocabulary, with `LiquidPress` for touch response and `DampedDragAnimation` for
anything a finger throws.

Three motion roles, so forty components do not invent forty curves:

| role | feel | used by |
| --- | --- | --- |
| `press` | fast, near-critically damped | every tier-1 control |
| `settle` | slower, slight overshoot | selection moving between slots, sheets |
| `follow` | tracks a finger 1:1, springs only on release | slider, drag, dismiss |

**Animate the light, not the layout, wherever there is a choice.** The repo
already establishes why: effect parameters are re-read every paint, so
animating an alpha or a lens amount costs nothing per frame, while animating a
size re-runs layout and — on the capture path — re-captures the backdrop.

### 2.5 Readability is the floor, not a trade-off

Every rule above is subordinate to this one. A surface that is beautiful and
hard to read is a defect, and the material makes that failure easy to ship
because it looks best over exactly the busy, high-contrast backgrounds that
ruin legibility.

The governing rule, which is checkable rather than tasteful:

> **A glass surface must be legible without knowing what is behind it.** If a
> label's contrast depends on where the element happens to sit, the tint is too
> light — not the label too small.

Three mechanisms enforce it, in increasing order of effort:

1. **The reader's own setting wins.** `LiquidGlassTheme.of` now returns an
   opaque `container` when `MediaQuery.highContrast` is set, and `DrawBackdrop`
   clamps that element to `GlassQuality.plain`, dropping the lens and the
   shaded rim. Between them the surface stops being transparent and stops
   moving. This reaches every component at once, because they all take colours
   from the theme and tiers from the same resolver.
2. **Measure, when the surface cannot be opaque.** `BackdropLuminance` (behind
   `LiquidAdaptivePanel`) reads the pixels the glass actually samples and
   retunes brightness, contrast and blur from them. That is the honest answer
   for a surface that must stay translucent over unknown content.
3. **Blur hard enough over text.** Chrome laid over running text has to blur
   the page past readability — half-blurred type showing through a bar is
   worse than either extreme. `fusion.frag:184` fixes the floor empirically at
   nine taps, "four leaves the type legible through the glass, which is the one
   thing chrome must not do".

**Two gaps to know about.** Flutter surfaces `accessibleNavigation`,
`invertColors`, `highContrast`, `disableAnimations` and `boldText` — and
*nothing* for **Reduce Transparency**, the setting that most directly asks a
glass library to stand down. Reaching it needs a platform channel. And
`highContrast` itself is only reported on iOS 13+ and Android API 34+. So every
app should also offer its own "reduce visual effects" switch, which is what
`GlassQualityScope` is for; the library cannot do this on the app's behalf.

Only `disableAnimations` was honoured before this pass, and only inside
`liquid_menu.dart`. Honouring it everywhere motion is spring-driven is
outstanding work.

---

## 3. The performance contract

### 3.1 What the two paths cost

Measured on a OnePlus PKJ110 (Android 16, 360×792 @ 4.0×), release build,
`totalSpan` net of a same-run no-glass baseline, one pinned glass bar over a
flung feed:

| path | net cost per element | shares between elements |
| --- | --- | --- |
| capture (`toImageSync` + lens) — today's tier 1/2 | **+2.66 ms** | no |
| compositor (`BackdropFilterLayer`), no lens — today's tier 3 | **+0.13 ms** | yes, via `BackdropGroup` |
| compositor **with** lens, on a real `LiquidPanel` | **+2.90 ms** | yes |

**The third row is a negative result, and it replaces an earlier estimate of
+0.14 ms.** That figure was real but came from a synthetic probe: a bare
`BackdropFilter` inside a `ClipRRect`, two hand-built filters, no rim, no drop
shadow, no surface tint. Re-measured on an actual `LiquidPanel` — the same
device, the same harness, both paths alternated inside one build — the
compositor path is *slightly slower* than the capture path it was meant to
replace, and its raster time is 2–3× higher (3.2–4.2 ms against 0.9–1.6 ms).

What did survive the re-measurement:

- **The picture matches.** compositor vs capture = 0.83 mean absolute
  difference, with **0.0** across the element's core — the refraction is
  correct and correctly placed.
- **Nothing leaks.** Outside the panel, both paths sit at 0.05 against the
  untouched page, so the clip holds.

So the mechanism works and the economics do not, at least not yet. The cost is
in the extra offscreen passes: the compositor path forces a clip *layer* around
an arbitrary continuous-corner path and then nests a `BackdropFilterLayer`
inside it per filter stage, where the capture path runs the whole chain over
one small element-sized texture. Which of those dominates is not yet measured —
and cannot be measured in a widget test, because `flutter_test` runs on Skia
where `isRuntimeShaderSupported()` is false and `lens()` returns early, so the
chain under test is not the chain the device builds.

**Consequences for this design.** The tier-1/2 budget stays at the capture
path's ~2.7 ms per element until this is resolved, which makes §3.2's rules
(one `BackdropLayer` per screen, fuse instead of stack, cap the transforming
minority) load-bearing rather than merely tidy. It does not change the
component inventory, and it does not touch tier 3, which was already on the
compositor path and already cheap.

The work is landed but **off by default** as
`RenderDrawBackdrop.useCompositorLens`, with the existing 222 tests passing
unchanged. Turning it on is a measurement tool, not yet a recommendation.

The same change closes a gap in the public escape hatch.
`CustomBackdropEffects.fragmentShaderEffect` guards only on
`isRuntimeShaderSupported()` (`backdrop_effect_scope.dart:149`), not on
quality — so a caller who adds their own shader on a backdrop that *is* painted
behind, on a device the tier classifier put at `plain`, lands on
`_paintNativeBackdrop` and has their shader silently composed away. Nothing in
the library hits this today (`LiquidFusion` resolves its program to `null` at
`plain` and routes to `_PlainFusion` instead, `liquid_fusion.dart:456` and
`:224`), but an app using the documented escape hatch can. Nesting the layers
instead of composing them fixes it without a guard.

### 3.2 The rules that keep a component cheap

A component is on the cheap path when all five of `_usesNativeFilter`'s
conditions hold (`draw_backdrop.dart:783`): the backdrop is painted behind it,
there is no `onDrawBackdrop`, no `exportedBackdrop`, it is not inside a capture
— plus, after the change, that its effects are expressible as a filter chain.

So, as design rules:

1. **Default every new component to a backdrop that is simply behind it.** A
   component that reaches for `WrappedBackdrop`, `CanvasBackdrop` or
   `onDrawBackdrop` has left the cheap path and needs to justify it.
2. **One `BackdropLayer` per screen, not per component.** Wrap the page once;
   share it. Sibling glass in one `BackdropGroup` shares a single read.
3. **Fuse instead of stacking.** A toolbar of five glass buttons is one
   `LiquidFusion`, not five elements — and the fused body is what
   `LiquidNavigationBar` already runs on.
4. **Cap the transforming minority.** Exactly four shipped components transform
   their source and therefore cannot be cheap: `LiquidMagnifier` (samples
   elsewhere at >1×), `LiquidSlider`'s thumb and `LiquidToggle`'s knob (squash
   their track via `WrappedBackdrop`), and `LiquidBottomTabs`' pill. No new
   component joins that list without a measurement showing it must.

### 3.3 Where glass is the wrong answer

A complete library has to say where the material does not belong. Three places:

- **Behind sustained reading.** Body copy, code, tables. Text sits on an opaque
  surface inside a glass frame, not on the glass: refraction that moves under a
  paragraph while the page scrolls is the most tiring thing this material can
  do. The converse is a hard requirement on tiers 2 and 3 — chrome laid *over*
  running text must blur hard enough that the page beneath stops being
  readable, which is what `fusion.frag:184` settles when it takes nine taps
  rather than four ("four leaves the type legible through the glass, which is
  the one thing chrome must not do"). Half-blurred type showing through a bar
  is worse than either extreme.
- **Text input interiors.** A field's fill is opaque or near-opaque; the glass
  is the container around it, and the caret and selection need a stable
  background.
- **Anything that repeats.** List rows, table cells, grid items. Per-row glass
  multiplies the one cost that does not share and reads as noise; the *section*
  is glass, the rows are not.

### 3.4 Degrade by scenario, not only by device

`GlassDeviceTier` answers "what can this phone afford". It does not answer
"does this surface need the effect at all", and that second question is worth
more than the first:

| | net cost per element |
| --- | --- |
| `liquid` on the capture path | **+2.66 ms** |
| `plain` — Gaussian blur behind the tint, compositor, no capture | **+0.13 ms** |

**Twenty to one.** Dropping to `plain` is the single largest lever in the
library, it needs no new code, and on most surfaces it costs nothing visible —
the refraction is a rim effect whose entire measured weight is 2.10 mean
absolute difference, and it is invisible under a heavy tint.

So the tier is a property of the *scenario*, and the default is stated per
tier rather than left to the device:

| tier | default | why |
| --- | --- | --- |
| 3 overlay — sheets, dialogs, menus, toasts, popovers | **`plain`, always** | already pinned by `isCompositorOnly`; a tinted surface over a dimmed page has no visible refraction to lose |
| 2 surface — bars, cards, panels | `liquid` **only when it moves over live content** | a card on a static page shows the lens once, at a cost paid every frame |
| 1 control — buttons, chips, toggles | `liquid` | small, and the rim is the whole point of the material at this size |
| 0 flush | n/a | no glass |
| anything behind sustained text | **`plain`** | §2.5 |
| anything that repeats (rows, cells, grid items) | **not glass at all** | §3.3 |

Two consequences for the components in §4. `LiquidCard`, `LiquidListSection`,
`LiquidBanner` and `LiquidDataTable` default to `plain` — they are containers
for reading. `LiquidTopBar`, `LiquidBottomTabs` and `LiquidNavigationBar`
default to `liquid`, because pinned chrome over a scrolling page is the one
case where the refraction is continuously visible and is the reason to use this
material at all.

And the lever is already exposed three ways, so an app can always override:
`DrawBackdrop.quality` for one element, `GlassQualityScope` for a subtree,
`GlassDeviceTier.instance.classifier` or `pinnedQuality` for the whole app.

---

## 4. The component set

Tier from §2.1. "Path" is cheap (compositor) or capture.

### 4.1 Interaction primitives — all ✓

`LiquidInteraction` (pointer-following feedback without claiming the gesture),
`LiquidInkHighlight`, `InteractiveHighlight`, `LiquidPress`,
`DampedDragAnimation`. Every new control below is built from these rather than
from `GestureDetector` directly, so drag-select and pointer tracking behave the
same everywhere.

### 4.2 Actions

| component | tier | shape | motion | path | |
| --- | --- | --- | --- | --- | --- |
| `LiquidButton` | 1 | Capsule | press | cheap | ✓ |
| `LiquidButtonGroup` | 1 | Capsule, fused | press | cheap | ✓ |
| `LiquidIconButton` | 1 | Capsule (square-ish) | press | cheap | **new** |
| `LiquidChip` | 1 | Capsule | press + settle on select | cheap | **new** |
| `LiquidFab` | 2 | Capsule | press + settle on extend | cheap | **new** |
| `LiquidSplitButton` | 1 | Capsule, fused pair | press | cheap | **new** |

`LiquidIconButton` is not `LiquidButton` with an icon: it needs a square
touch target with a capsule visual, and its highlight must centre on the icon
rather than the box. `LiquidFab` sits at tier 2 because it floats over the page
rather than resting on a surface — and extending it animates width, which is
the one place layout animation is unavoidable.

### 4.3 Selection and value

| component | tier | shape | motion | path | |
| --- | --- | --- | --- | --- | --- |
| `LiquidToggle` | 1 | Capsule | follow + settle | capture (knob) | ✓ |
| `LiquidSegmentedControl` | 1 | Capsule | settle | cheap | ✓ |
| `LiquidSlider` | 1 | Capsule | follow | capture (thumb) | ✓ |
| `LiquidCheckbox` | 1 | RoundedRectangle | press + settle | cheap | **new** |
| `LiquidRadio` | 1 | Capsule | press + settle | cheap | **new** |
| `LiquidStepper` | 1 | Capsule, fused triple | press, repeat on hold | cheap | **new** |
| `LiquidRangeSlider` | 1 | Capsule | follow ×2 | capture | **new** |
| `LiquidWheelPicker` | 2 | RoundedRectangle | follow + settle | cheap | **new** |

`LiquidCheckbox` is the one place a rounded rectangle beats a capsule at control
scale — a capsule checkbox reads as a radio. Its check mark draws with the
accent, and the box itself is glass.

`LiquidWheelPicker` is the foundation for date and time pickers: a scrolling
column under a glass selection band. The band is the glass; the rows are not
(§3.3). This is deliberately *not* a per-row effect.

### 4.4 Text input — all new

| component | tier | shape | notes |
| --- | --- | --- | --- |
| `LiquidTextField` | 2 frame | RoundedRectangle | opaque interior; glass is the frame |
| `LiquidSearchField` | 1 | Capsule | opaque interior; expands to a results surface |
| `LiquidTextArea` | 2 frame | RoundedRectangle | as above, multi-line |

The whole category follows §3.3: the container is glass, the field is not. The
focus transition animates the frame's highlight alpha and rim, never a blur
radius — a field whose backdrop sharpens as you type is a distraction.

### 4.5 Containers

| component | tier | shape | path | |
| --- | --- | --- | --- | --- |
| `LiquidPanel` | 2 | any | cheap | ✓ |
| `LiquidAdaptivePanel` | 2 | any | capture (reads pixels) | ✓ |
| `LiquidFusion` | 1–2 | metaball body | cheap | ✓ |
| `LiquidCard` | 2 | RoundedRectangle | cheap | **new** |
| `LiquidListSection` | 2 | RoundedRectangle | cheap | **new** |
| `LiquidTile` | 0 | — | — | **new** |
| `LiquidExpansionTile` | 0 in a 2 | — | — | **new** |
| `LiquidDivider` | 0 | — | — | **new** |
| `LiquidBanner` | 2 | UnevenRoundedRectangle | cheap | **new** |

`LiquidListSection` is the answer to "glass list rows": one glass surface, many
plain rows, with `LiquidInteraction` supplying per-row feedback and
`LiquidDivider` between them. `LiquidTile` is therefore tier 0 — it has no glass
of its own and only exists to standardise the row's layout, leading/trailing
slots, and press feedback.

`LiquidAdaptivePanel` stays on the capture path by nature: it reads sampled
pixels back to Dart to retune itself. That is a documented exception, not a
defect.

### 4.6 Navigation

| component | tier | shape | path | |
| --- | --- | --- | --- | --- |
| `LiquidBottomTabs` | 2 | Capsule + pill | capture (pill) | ✓ |
| `LiquidNavigationBar` | 2 | fused islands | cheap | ✓ |
| `LiquidTopBar` | 2 | UnevenRoundedRectangle | cheap | **new** |
| `LiquidTabBar` | 1 | Capsule | cheap | **new** |
| `LiquidSideRail` | 2 | UnevenRoundedRectangle | cheap | **new** |
| `LiquidPageIndicator` | 1 | Capsule, fused dots | cheap | **new** |

`LiquidTopBar` is the largest gap in the current set — every app has one, and
it is the single best case for the material: pinned chrome with the page
scrolling under it. It should collapse its title on scroll by animating
opacity and offset, never by animating the bar's height (§2.4).

`LiquidPageIndicator` is a natural fusion case — dots that merge as the active
one travels, which the metaball field gives for free.

### 4.7 Overlays

| component | tier | backdrop | path | |
| --- | --- | --- | --- | --- |
| `LiquidSheet` | 3 | `nativeBackdrop` | cheap | ✓ |
| `LiquidDialog` | 3 | `nativeBackdrop` | cheap | ✓ |
| `LiquidMenu` | 3 | `nativeBackdrop` | cheap | ✓ |
| `LiquidPopover` | 3 | `nativeBackdrop` | cheap | **new** |
| `LiquidActionSheet` | 3 | `nativeBackdrop` | cheap | **new** |
| `LiquidTooltip` | 3 | `nativeBackdrop` | cheap | **new** |
| `LiquidToast` | 3 | `nativeBackdrop` | cheap | **new** |
| `LiquidDatePicker` | 3 | `nativeBackdrop` | cheap | **new** |

The whole tier is already cheap and already correct — these are the components
where the existing `nativeBackdrop` path was designed to be used, and adding
five more costs almost nothing. `LiquidPopover` is the general case that
`LiquidMenu` is a specialisation of: an anchored surface that flips rather than
hanging off an edge, which `liquid_menu.dart` already solves and should be
factored out of.

**One caveat for iOS later:** if a native `UIGlassEffect` surface is ever
introduced, Flutter maps `Opacity` to `embeddedView.alpha`, and Apple documents
that alpha below 1 disables the glass. `showLiquidDialog` uses a
`FadeTransition` by default, so that transition would have to change before any
native surface could be used there.

### 4.8 Feedback — all new

| component | tier | shape | notes |
| --- | --- | --- | --- |
| `LiquidProgressBar` | 1 | Capsule | glass track, accent fill |
| `LiquidActivityIndicator` | 1 | Capsule | rotation, not a glass rebuild |
| `LiquidBadge` | 1 | Capsule | fuses with its anchor |
| `LiquidSkeleton` | 0 | inherits | a sweep over an opaque block |

`LiquidSkeleton` is tier 0 deliberately: a loading placeholder that blurs the
page behind it is both expensive and meaningless, since there is nothing to
show through yet.

### 4.9 Special

`LiquidMagnifier` ✓ — tier 1, capture path, permanently. It samples elsewhere at
>1× magnification, which no compositor filter can express. It stays the
documented exception.

---

## 5. Build order

Sequenced so that each step de-risks the next, and so nothing is written twice.

1. ~~Land the compositor lens path.~~ **Landed, off by default, and it does not
   pay off yet** (§3.1): correct picture, no leakage, but slower than the
   capture path on a real component. Not a prerequisite for anything below —
   the budget simply stays where it is. Worth one more round to find whether
   the clip layer or the nested stages dominate, on device, since a widget test
   cannot see this path at all.
2. **Extract the depth tiers** into a `GlassDepth` token, and move the seven
   hand-written recipes onto it. No behaviour change, and it is what stops the
   next thirty components from each inventing a blur radius.
3. **Factor `LiquidPopover`** out of `LiquidMenu`'s anchoring and flipping
   logic. Four new overlay components then cost almost nothing each.
4. **Fill the gaps that every app needs**, in this order: `LiquidTopBar`,
   `LiquidTextField`, `LiquidCard` + `LiquidListSection` + `LiquidTile`,
   `LiquidIconButton`, `LiquidToast`. This set is what makes the library usable
   as the only UI kit in an app rather than a decoration over Material.
5. **Complete the control set**: checkbox, radio, chip, stepper, progress,
   activity, badge.
6. **The rest**: pickers, side rail, tab bar, page indicator, range slider,
   expansion tile, banner, skeleton.

Steps 1 and 2 are prerequisites. Steps 3–6 are independently shippable.

---

## 6. What this design refuses

Worth writing down, because each of these is a plausible-sounding idea that
would cost more than it returns:

- **A glass tier per component.** Forty recipes is not a design system.
- **Per-row glass in lists.** Multiplies the one cost that does not share.
- **Glass behind body text.** The one thing chrome must not do.
- **Native platform-view backends.** On Android, no Flutter composition mode
  hands native code Flutter's pixels, so a native glass view has nothing to
  refract; on iOS, `UIGlassEffect` exposes only `init(style:)`, `tintColor` and
  `isInteractive`, so `lens(...)` and `blur(...)` have no receiver — it is a
  deletion of the effect API, not a port of it.
- **Duration-based motion.** Springs compose with interruption; durations do
  not, and every control here can be interrupted mid-animation.

---

## 7. Coverage against Flutter's Material library

Audited against every user-facing module exported by
`flutter/lib/material.dart` (Flutter 3.47), excluding `*_theme`, localisations,
icons, curves and other non-components. "—" means the Flutter widget is used
unchanged: it has no surface of its own, so there is nothing for the material
to do.

### 7.1 Actions

| Material | FluidGlass | |
| --- | --- | --- |
| `ElevatedButton`, `FilledButton`, `FilledButton.tonal`, `OutlinedButton`, `TextButton` | `LiquidButton` + a `variant` | ✓ / **needs variants** |
| `IconButton` | `LiquidIconButton` | **new** |
| `BackButton`, `CloseButton`, `DrawerButton`, `EndDrawerButton` | `LiquidIconButton` presets | **new** |
| `FloatingActionButton` (small / large / extended) | `LiquidFab` | **new** |
| `SegmentedButton` | `LiquidSegmentedControl` | ✓ |
| `ToggleButtons` | `LiquidToggleButtons` | **new** |
| `ActionChip`, `ChoiceChip`, `FilterChip`, `InputChip` | `LiquidChip` ×4 variants | **new** |
| `MaterialButton`, `ButtonBar` | — (deprecated upstream) | n/a |

`LiquidButton` today has no variant axis at all. Material's five are really
two questions — *filled or not*, *outlined or not* — which on glass become
*does the surface carry the accent* and *does the rim carry it*. Two booleans,
not five classes.

### 7.2 Communication

| Material | FluidGlass | |
| --- | --- | --- |
| `Badge` | `LiquidBadge` | **new** |
| `LinearProgressIndicator` | `LiquidProgressBar` | **new** |
| `CircularProgressIndicator` | `LiquidActivityIndicator` | **new** |
| `SnackBar` | `LiquidToast` | **new** |
| `MaterialBanner` | `LiquidBanner` | **new** |
| `Tooltip` | `LiquidTooltip` | **new** |

### 7.3 Containment

| Material | FluidGlass | |
| --- | --- | --- |
| `Scaffold` | **`LiquidScaffold`** | **new — prerequisite, see §7.7** |
| `Card` | `LiquidCard` | **new** |
| `BottomSheet`, `showModalBottomSheet` | `LiquidSheet` | ✓ |
| `Dialog`, `AlertDialog`, `SimpleDialog`, `AboutDialog` | `LiquidDialog` | ✓ |
| `Divider`, `VerticalDivider` | `LiquidDivider` | **new** |
| `ListTile` (+ `Checkbox`/`Radio`/`Switch` variants) | `LiquidTile` + the controls | **new** |
| `ExpansionTile`, `ExpansionPanel` | `LiquidExpansionTile` | **new** |
| `CarouselView` | `LiquidCarousel` | **new** |
| `CircleAvatar` | `LiquidAvatar` | **new** |
| `Drawer`, `DrawerHeader`, `UserAccountsDrawerHeader` | `LiquidDrawer` | **new** |
| `Scrollbar` | `LiquidScrollbar` | **new** |
| `RefreshIndicator` | `LiquidRefreshIndicator` | **new** |
| `DataTable`, `PaginatedDataTable` | `LiquidDataTable` — frame only, rows stay plain (§3.3) | **new** |
| `GridTile`, `GridTileBar` | `LiquidTile` in a grid | **new** |
| `ReorderableListView` | — (behaviour; wrap `LiquidTile`) | n/a |
| `Material`, `InkWell`, `InkResponse`, ink splashes | `LiquidInteraction`, `LiquidInkHighlight` | ✓ |
| `MergeableMaterial` | — | n/a |

### 7.4 Navigation

| Material | FluidGlass | |
| --- | --- | --- |
| `AppBar`, `SliverAppBar`, `FlexibleSpaceBar` | **`LiquidTopBar`** | **new — largest functional gap** |
| `BottomAppBar` | `LiquidNavigationBar` | ✓ |
| `NavigationBar`, `BottomNavigationBar` | `LiquidBottomTabs`, `LiquidNavigationBar` | ✓ |
| `NavigationRail` | `LiquidSideRail` | **new** |
| `NavigationDrawer` | `LiquidDrawer` | **new** |
| `TabBar`, `TabBarView` | `LiquidTabBar` | **new** |
| `SearchBar`, `SearchAnchor`, search view | `LiquidSearchField` | **new** |
| `Autocomplete` | `LiquidAutocomplete` | **new** |
| `MenuAnchor`, `MenuBar`, `SubmenuButton`, `MenuItemButton` | `LiquidMenu`, `LiquidPopover` | ✓ / **new** |
| `PopupMenuButton` | `LiquidMenu` | ✓ |

### 7.5 Selection

| Material | FluidGlass | |
| --- | --- | --- |
| `Checkbox` | `LiquidCheckbox` | **new** |
| `Radio` | `LiquidRadio` | **new** |
| `Switch` | `LiquidToggle` | ✓ |
| `Slider` | `LiquidSlider` | ✓ |
| `RangeSlider` | `LiquidRangeSlider` | **new** |
| `Stepper` (the multi-step **wizard**) | `LiquidStepper` | **new** |
| a numeric −/+ control (Cupertino, not Material) | `LiquidNumberStepper` | **new** |
| `showDatePicker`, `CalendarDatePicker`, `InputDatePickerFormField` | `LiquidDatePicker` | **new** |
| `showTimePicker` | `LiquidTimePicker` | **new** |
| `DropdownButton`, `DropdownMenu` | `LiquidDropdown` | **new** |
| (wheel column both pickers are built on) | `LiquidWheelPicker` | **new** |

§4.3 originally called the −/+ control `LiquidStepper`. That name belongs to
Material's wizard, which is a different component entirely; both are listed
here under their own names.

### 7.6 Text input

| Material | FluidGlass | |
| --- | --- | --- |
| `TextField`, `TextFormField`, `InputDecorator`, `InputBorder` | `LiquidTextField` (+ `LiquidTextArea`) | **new** |
| `AdaptiveTextSelectionToolbar`, `TextSelectionToolbar` | `LiquidSelectionToolbar` | **new** |
| text-selection `Magnifier` | `LiquidMagnifier` | ✓ |
| `SpellCheckSuggestionsToolbar` | composed from `LiquidMenu` | ✓ |
| `SelectableText`, `SelectionArea` | — (no surface of their own) | n/a |

`LiquidSelectionToolbar` is a better fit for this material than almost anything
else in the list: a small floating surface over arbitrary page content, already
the exact case `NativeBackdrop`'s doc names. It and `LiquidMagnifier` together
replace the pair Flutter already swaps per platform, so a text field can be
fully glass without either being written by hand.

### 7.7 The prerequisite the audit surfaced

`LiquidScaffold` is not one more container. The README states the constraint
that makes it structural:

> A `Backdrop`, passed explicitly. There is no inherited lookup; a glass widget
> cannot invent what it refracts. If threading it through gets tedious, put the
> `LayerBackdrop` in an `InheritedWidget` of your own.

That is workable for twelve components and untenable for forty-five — every
call site would thread `backdrop:` by hand, and every app would write the same
`InheritedWidget`. `LiquidScaffold` supplies it: it owns the one
`BackdropLayer` for the page, publishes it through a `BackdropScope`, and slots
the top bar, bottom bar, FAB, drawer and snackbar host around it.

It is also where the performance rules in §3.2 stop being advice and become
the default. "One `BackdropLayer` per screen" is a property of the scaffold,
not a thing each app remembers. Every new component then takes an optional
`backdrop:` that falls back to `BackdropScope.of(context)`.

### 7.8 Revised build order

Replacing §5 steps 4–6:

1. ~~Compositor lens path.~~ Landed but parked; see §3.1. Not a prerequisite.
2. **Extract the depth tiers into a token.** Now the first real step.
3. **`LiquidScaffold` + `BackdropScope`.** Everything after it is written
   against an inherited backdrop instead of a threaded parameter, so doing it
   third avoids rewriting forty signatures later.
4. Factor `LiquidPopover` out of `LiquidMenu`.
5. The set an app cannot ship without: `LiquidTopBar`, `LiquidTextField`,
   `LiquidCard` + `LiquidListSection` + `LiquidTile` + `LiquidDivider`,
   `LiquidIconButton`, `LiquidButton` variants, `LiquidToast`, `LiquidAvatar`,
   `LiquidScrollbar`.
6. Controls: checkbox, radio, chips ×4, toggle buttons, progress, activity,
   badge, number stepper.
7. Structure: drawer, side rail, tab bar, expansion tile, banner, refresh
   indicator, page indicator.
8. Input and pickers: search field, autocomplete, dropdown, wheel picker, date
   picker, time picker, selection toolbar, range slider.
9. Long tail: carousel, data table frame, stepper wizard, skeleton, grid tile.

Steps 2 and 3 are prerequisites and strictly ordered — the token before the
components that use it, the scaffold before the forty signatures that would
otherwise thread `backdrop:` by hand. 4–9 are independent.
