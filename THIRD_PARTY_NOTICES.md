# Third-party notices

FluidGlass is a port of two Apache-2.0 licensed Kotlin/Compose projects by
[Kyant](https://github.com/Kyant0); its soft component family is a port of a
third Apache-2.0 licensed Kotlin/Compose project, listed last. FluidGlass is itself distributed under the
Apache License 2.0; the licence text is in [LICENSE](LICENSE) and the
attribution notice in [NOTICE](NOTICE).

## AndroidLiquidGlass (`backdrop`)

- Source: <https://github.com/Kyant0/AndroidLiquidGlass>
- Copyright 2025 Kyant
- Licence: Apache License 2.0

The following are derived from it, keeping the original structure, maths and
constants:

| FluidGlass | AndroidLiquidGlass |
| --- | --- |
| `shaders/refraction.frag` | `internal/Shaders.kt` (`RoundedRectRefractionShaderString`) |
| `shaders/refraction_dispersion.frag` | `internal/Shaders.kt` (`RoundedRectRefractionWithDispersionShaderString`) |
| `shaders/highlight_default.frag` | `internal/Shaders.kt` (`DefaultHighlightShaderString`) |
| `shaders/highlight_ambient.frag` | `internal/Shaders.kt` (`AmbientHighlightShaderString`) |
| `lib/src/backdrop.dart` | `Backdrop.kt` |
| `lib/src/backdrop_effect_scope.dart` | `BackdropEffectScope.kt` |
| `lib/src/draw_backdrop.dart` | `DrawBackdropModifier.kt` |
| `lib/src/backdrops/*` | `backdrops/*` |
| `lib/src/effects/*` | `effects/*` |
| `lib/src/highlight/*` | `highlight/*` |
| `lib/src/shadow/*` | `shadow/*` |
| `lib/src/internal/glass_painters.dart` | `highlight/HighlightModifier.kt`, `shadow/ShadowModifier.kt`, `shadow/InnerShadowModifier.kt` |
| `example/lib/catalog/**` | `app/src/commonMain/kotlin/com/kyant/backdrop/catalog/**` |
| `example/shaders/interactive_highlight.frag` | inline AGSL in `catalog/utils/InteractiveHighlight.kt` |
| `example/shaders/sdf.frag` | `catalog/utils/SdfShader.kt` (`SdfShaderString`) |
| `example/shaders/progressive_blur.frag` | inline AGSL in `catalog/destinations/ProgressiveBlurContent.kt` |

`example/assets/wallpaper_light.webp` and `example/assets/clock_sdf.webp` are
taken unmodified from that project's `app/src/commonMain/composeResources`.

## Shapes

- Source: <https://github.com/Kyant0/Shapes>
- Copyright 2025 Kyant
- Licence: Apache License 2.0

`lib/src/shapes/*` is derived from it — in particular
`continuous_curvature_corner_builder.dart` and
`rounded_rectangle_outline.dart`, which carry over the G2-continuous corner
solution verbatim.

## coui17 (and the projects it is forked from)

- Source: <https://github.com/Costben/coui17>
- Copyright 2025-2026, compose-coui-ui contributors
- Licence: Apache License 2.0
- Forked from <https://github.com/suqi8/coui> (Copyright the COUI contributors,
  Apache License 2.0), itself forked from
  <https://github.com/compose-miuix-ui/miuix> (Copyright YuKongA and the
  compose-miuix-ui contributors, Apache License 2.0).

The soft family is derived from its `coui-ui`, `coui-squircle` and `coui-blur`
modules, keeping their metrics, colours, springs, curves and shader maths:

| FluidGlass | coui17 |
| --- | --- |
| `lib/src/soft/foundation/soft_colors.dart` | `theme/Colors.kt` |
| `lib/src/soft/foundation/soft_theme.dart` | `theme/TextStyles.kt`, `theme/` theme wiring |
| `lib/src/soft/foundation/soft_squircle.dart` | `squircle/SquirclePath.kt`, `squircle/SquircleShape.kt` |
| `lib/src/soft/foundation/soft_motion.dart` | `anim/*`, `utils/SpringUtils.kt` |
| `lib/src/soft/foundation/soft_touch_motion.dart` | `basic/` touch motion |
| `lib/src/soft/foundation/soft_pressable.dart` | `utils/PressFeedback.kt`, `utils/` state-layer indication |
| `lib/src/soft/foundation/soft_spot_light.dart`, `shaders/soft_spot_light.frag` | `basic/SpotLightEffect.kt` |
| `lib/src/soft/foundation/soft_glass.dart`, `shaders/soft_bloom_stroke.frag` | `basic/GlassSurface.kt`; `blur/highlight/HighlightStyle.kt`, `blur/internal/Shaders.kt` |
| `lib/src/soft/foundation/soft_meta_ball.dart`, `shaders/soft_meta_ball.frag`, `shaders/soft_meta_ball_edge.frag`, `shaders/soft_caustic.frag` | `basic/MetaBallSurface.kt`, `basic/NativeMaterialEdge.kt`, `basic/MaterialShadowEdge.kt`, `basic/MaterialCausticShadow.kt` |
| `lib/src/soft/components/basic/*` | `basic/Card.kt`, `basic/Component.kt`, `basic/SmallTitle.kt`, `basic/Divider.kt` |
| `lib/src/soft/components/badge/*` | `basic/Badge.kt` |
| `lib/src/soft/components/navigation/*` | `basic/BottomFloatingNavigationBar.kt`, `basic/BottomFloatingAccessoryNavigationBar.kt` |
| `lib/src/soft/components/selection/soft_switch.dart` | `basic/Switch.kt` (reference commit `2b013540552e551cb51b1c5b4cfeeaf057cba2f3`) |
| `lib/src/soft/components/selection/soft_number_picker.dart`, `soft_date_picker.dart` | `basic/NumberPicker.kt`, `basic/DatePicker.kt` |
| `lib/src/soft/components/basic/soft_expandable_list.dart` | `basic/ExpandableList.kt` |
| `lib/src/soft/components/feedback/soft_pull_to_refresh.dart` | `basic/PullToRefresh.kt` (Flutter scroll notifications; the ring, capsule, orbit and completion drawing) |
| `lib/src/soft/components/feedback/soft_notification_snack_bar.dart`, `soft_notification_swipe_box.dart` | `basic/NotificationSnackBar.kt`, `basic/NotificationSwipeBox.kt` (card content and swipe container) |
| `lib/src/soft/components/menu/soft_horizontal_popup_menu.dart` | `basic/HorizontalPopupMenu.kt` |
| `lib/src/soft/components/{bars,button,dialog,feedback,input,menu,selection,sheet}/*` | the matching components under `basic/` (top app bar, tab row, chip tab, buttons, chip, dialog, loading dialog, snackbar, top tips, tooltip, progress, page indicator, empty state, text field, input view, search bar, popup list, dropdown, checkbox, radio button, slider, bottom sheet) |
| `lib/src/soft/components/basic/soft_glyph_icon.dart` | `coui-icons` (Regular vectors, unmodified paths) |
| `shaders/soft_capsule_edge.frag` | the capsule edge model of `basic/MetaBallSurface.kt` |
| `example/lib/soft_demo/reference_page.dart` | the component sections of its `example` |

`shaders/soft_blend_tint.frag` is not derived from it: it implements the
colour-dodge, overlay and luminosity blend modes of the W3C Compositing and
Blending specification.
