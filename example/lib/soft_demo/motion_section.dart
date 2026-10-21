import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/widgets.dart';

/// A live comparison of the reference's spotlight presets and touch motion.
class SoftMotionSection extends StatefulWidget {
  const SoftMotionSection({super.key});

  @override
  State<SoftMotionSection> createState() => _SoftMotionSectionState();
}

class _SoftMotionSectionState extends State<SoftMotionSection> {
  final SoftTouchMotionState _motion = SoftTouchMotionState();
  int _preset = 0;
  double _intensity = 1;
  double _radius = 1;
  bool _follow = true;
  bool _reduce = false;
  bool _loading = false;

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final List<SoftSpotLightParams> presets = <SoftSpotLightParams>[
      SoftSpotLightParams.capsule2(theme.isDark),
      SoftSpotLightParams.circle1(theme.isDark),
      SoftSpotLightParams.translucentLarge1(theme.isDark),
      SoftSpotLightParams.roundRect1(theme.isDark),
    ];
    final SoftSpotLightParams preset = presets[_preset];
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: _reduce || softReduceMotion(context)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SoftCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('按住并拖动，松手观察光晕扩散与弹簧回落', style: theme.textStyles.body2),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    const Expanded(child: Text('开关拖尾与加载动画')),
                    SoftSwitch(
                      checked: _follow,
                      isLoading: _loading,
                      onChanged: (bool value) =>
                          setState(() => _follow = value),
                      loadingSemanticLabel: '加载中',
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (int i = 0; i < presets.length; i++)
                      SoftTextButton(
                        text: <String>['胶囊', '圆形', '弹层', '圆角矩形'][i],
                        variant: _preset == i
                            ? SoftButtonVariant.primary
                            : SoftButtonVariant.normal,
                        onPressed: () => setState(() => _preset = i),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                Center(
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      disableAnimations: _reduce || softReduceMotion(context),
                    ),
                    child: SoftTouchMotion(
                      state: _motion,
                      followFinger: _follow,
                      color: theme.colors.secondaryVariant,
                      borderRadius: BorderRadius.circular(
                        _preset == 1 ? 56 : 28,
                      ),
                      light: preset.copyWith(
                        endIntensity: preset.endIntensity * _intensity,
                        endRadius: preset.endRadius * _radius,
                      ),
                      child: SizedBox(
                        width: _preset == 1 ? 112 : 220,
                        height: 112,
                        child: const Center(child: Text('按住这里')),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _motion,
                  builder: (BuildContext context, Widget? child) => Text(
                    '光强 ${_motion.lightProgress.toStringAsFixed(2)} · '
                    '位移 ${_motion.translation.distance.toStringAsFixed(1)} · '
                    '缩放 ${_motion.scaleX.toStringAsFixed(2)} / ${_motion.scaleY.toStringAsFixed(2)}',
                    style: theme.textStyles.body2,
                  ),
                ),
                const SizedBox(height: 16),
                Text('光晕强度 ×${_intensity.toStringAsFixed(1)}'),
                SoftSlider(
                  value: _intensity,
                  min: 0,
                  max: 2,
                  onChanged: (double value) =>
                      setState(() => _intensity = value),
                ),
                Text('光晕范围 ×${_radius.toStringAsFixed(1)}'),
                SoftSlider(
                  value: _radius,
                  min: 0.5,
                  max: 2,
                  onChanged: (double value) => setState(() => _radius = value),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    SoftTextButton(
                      text: _follow ? '跟手：开' : '跟手：关',
                      onPressed: () => setState(() => _follow = !_follow),
                    ),
                    SoftTextButton(
                      text: _reduce ? '减少动画：开' : '减少动画：关',
                      onPressed: () => setState(() => _reduce = !_reduce),
                    ),
                    SoftTextButton(
                      text: _loading ? '结束加载' : '加载动效',
                      onPressed: () => setState(() => _loading = !_loading),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
