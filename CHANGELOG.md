# Changelog

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
