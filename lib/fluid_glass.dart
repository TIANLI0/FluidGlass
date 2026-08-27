/// A customizable Liquid Glass effect library for Flutter.
///
/// A port of [Kyant0/AndroidLiquidGlass](https://github.com/Kyant0/AndroidLiquidGlass)
/// (`backdrop`, Apache-2.0) together with the continuous-corner shapes from
/// [Kyant0/Shapes](https://github.com/Kyant0/Shapes).
///
/// Wrap the content a glass element should refract in a [BackdropLayer], then
/// draw glass over it with [DrawBackdrop]:
///
/// ```dart
/// final backdrop = LayerBackdrop();
///
/// Stack(
///   children: [
///     BackdropLayer(backdrop: backdrop, child: Image.asset('wallpaper.webp')),
///     DrawBackdrop(
///       backdrop: backdrop,
///       shape: () => const Capsule(),
///       effects: (scope) => scope
///         ..vibrancy()
///         ..blur(2)
///         ..lens(12, 24),
///       child: const Text('Liquid Glass'),
///     ),
///   ],
/// )
/// ```
library;

import 'src/internal/shader_programs.dart';

export 'src/animation/damped_drag_animation.dart';
export 'src/animation/spring.dart';
export 'src/backdrop.dart';
export 'src/backdrop_effect_scope.dart'
    show BackdropEffectGeometry, BackdropEffectScope, ShaderEffectConfigurator;
export 'src/backdrops/canvas_backdrop.dart';
export 'src/backdrops/combined_backdrop.dart';
export 'src/backdrops/empty_backdrop.dart';
export 'src/backdrops/layer_backdrop.dart'
    show BackdropLayer, LayerBackdrop, LayerBackdropSource, RenderBackdropLayer;
export 'src/backdrops/wrapped_backdrop.dart';
export 'src/components/interactive_highlight.dart';
export 'src/components/liquid_bottom_tabs.dart';
export 'src/components/liquid_button.dart';
export 'src/components/liquid_button_group.dart';
export 'src/components/liquid_menu.dart';
export 'src/components/liquid_panel.dart';
export 'src/components/liquid_segmented_control.dart';
export 'src/components/liquid_slider.dart';
export 'src/components/liquid_toggle.dart';
export 'src/draw_backdrop.dart'
    show
        BackdropEffectsBuilder,
        DrawBackdrop,
        GlassDrawCallback,
        GlassInnerShadowGetter,
        GlassShadowGetter,
        GlassShapeGetter,
        HighlightGetter,
        OnDrawBackdropCallback,
        RenderDrawBackdrop,
        RenderGlassTransform;
export 'src/effects/blur.dart';
export 'src/effects/color_filter.dart';
export 'src/effects/custom_effect.dart';
export 'src/effects/lens.dart';
export 'src/gestures/drag_gesture_inspector.dart';
export 'src/glass_layer.dart';
export 'src/highlight/highlight.dart';
export 'src/highlight/highlight_style.dart';
export 'src/internal/blur_sigma.dart' show blurRadiusToSigma;
export 'src/internal/shader_programs.dart'
    show FragmentShaderCache, isRenderEffectSupported, isRuntimeShaderSupported;
export 'src/quality/glass_device_tier.dart';
export 'src/quality/glass_quality.dart';
export 'src/shadow/shadow.dart';
export 'src/shapes/glass_outline.dart';
export 'src/shapes/rectangle_corner_radii.dart';
export 'src/shapes/rounded_corner_style.dart';
export 'src/shapes/rounded_rectangle_outline.dart';
export 'src/shapes/rounded_rectangular_shape.dart';
export 'src/shapes/shape_interop.dart';
export 'src/theme/liquid_glass_colors.dart';
export 'src/theme/liquid_glass_theme.dart';

/// Entry points for setting the library up.
abstract final class FluidGlass {
  /// Loads the fragment programs the effects need.
  ///
  /// Optional: they load on first use anyway, and elements render without their
  /// shader-based effects until then. Awaiting this in `main` avoids that first
  /// unrefracted frame.
  static Future<void> ensureInitialized() => FluidGlassPrograms.instance.load();

  /// Whether the fragment programs have finished loading.
  static bool get isReady => FluidGlassPrograms.instance.isReady;
}
