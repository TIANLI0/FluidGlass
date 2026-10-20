# Component performance and usability

This pass builds on the existing capture, quality-tier, spring and accessibility
work. Explicit backdrop ownership remains unchanged: each control still receives
the source it samples. Existing `children` button calls and explicit slider
parameters continue to work.

## Rendering

Slider, toggle and segmented-control translations now subscribe to their
animations in a shared render object. A tick updates Flutter's `RenderTransform`
directly, preserving paint transforms, hit testing and semantic bounds without
rebuilding a `ListenableBuilder` or allocating a new Transform widget. Listener
attachment follows the render object's attach/detach lifecycle. Static content
remains the same subtree throughout an interaction.

`test/animation_build_cost_test.dart` observes Flutter's widget-build callback
over 12 animation frames after input. All three controls move with zero widget
builds in that window. Existing capture-count, transform, source-sampling and
idle-frame tests continue to cover the paths around the new transform.

Buttons omit the surface callback when there is no surface to draw and skip its
isolating save-layer when there is no hue tint. A hue-tinted button retains
isolation because its blend mode needs that boundary. Stepped slider callbacks
are deduplicated independently of the continuously moving thumb, avoiding
redundant parent work within one stop.

These are verified reductions in work, not a claimed percentage improvement in
device frame time. Widget tests run on the host renderer; they cannot establish
Impeller raster timings or mobile GPU behavior. For frame-time comparisons, run
the existing `example/lib/probe_live_perf.dart` in profile mode on the same
device before and after the change, with the same scene and quality tier. Check
build, raster and total frame spans; a lower build cost alone does not establish
a faster GPU path.

## Input contract

- Controls stay controlled: applications own selected values and return them on
  rebuild. Null actions disable pointer, keyboard and accessibility activation.
- Buttons accept either one `child` or a `children` row. Focus and tooltips use
  Flutter's own focus/action and semantics mechanisms.
- Sliders use defaults for their normal 0..1 case. Value formatting describes
  real application units, independently of the underlying numeric range.
- Slider start/change/end callbacks distinguish UI updates from final writes.
  Cancellation ends visual feedback without an end callback. Already reported
  values remain with the caller; they are not silently rolled back.
- A cancelled toggle restores the caller's selection without reporting a change.
- The slider's transparent input area defaults to 48 pixels high, while the
  visible track and thumb remain 6 and 24 pixels high. For compact existing
  layouts, explicitly pass `touchTargetHeight: 24`.
- A segmented control has a finite fallback width in an unbounded Row. Its
  selected index must identify an existing segment, and height must exceed its
  six pixels of total thumb inset.

The nullable action field types can require null checks in code that reads and
invokes widget fields directly. Normal constructor call sites remain valid.

## Verification

```sh
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
cd example
flutter test --no-pub --reporter expanded
```

`test/component_usability_test.dart` covers keyboard activation and traversal,
focus indication, disabled controls, pointer cancellation, slider callback
ordering and deduplication, touch targeting, RTL adjustment and unbounded layout.
