# Third-party notices

FluidGlass is a port of two Apache-2.0 licensed Kotlin/Compose projects by
[Kyant](https://github.com/Kyant0). FluidGlass is itself distributed under the
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
