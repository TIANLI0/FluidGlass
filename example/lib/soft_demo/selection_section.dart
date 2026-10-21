import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/widgets.dart';

/// The checkbox, radio button, slider and range slider sections of the
/// reference gallery: a card of each, with every variant it shows.
class SoftDemoSelectionSection extends StatelessWidget {
  const SoftDemoSelectionSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SoftSmallTitle('复选框'),
        _CheckboxDemo(),
        SoftSmallTitle('单选按钮'),
        _RadioButtonDemo(),
        SoftSmallTitle('滑块'),
        _SliderDemo(),
        SoftSmallTitle('范围滑块'),
        _RangeSliderDemo(),
      ],
    );
  }
}

/// A card inset 16 from the sides with 16 below, as each gallery card sits.
class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SoftCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

const Widget _divider = SoftDivider(indent: 16, endIndent: 16);

class _CheckboxDemo extends StatefulWidget {
  const _CheckboxDemo();

  @override
  State<_CheckboxDemo> createState() => _CheckboxDemoState();
}

class _CheckboxDemoState extends State<_CheckboxDemo> {
  bool _first = false;
  bool _second = true;
  SoftCheckboxState _tri = SoftCheckboxState.indeterminate;
  bool _endChecked = false;
  bool _startChecked = false;

  void _cycle() => setState(() {
    _tri = switch (_tri) {
      SoftCheckboxState.off => SoftCheckboxState.indeterminate,
      SoftCheckboxState.indeterminate => SoftCheckboxState.on,
      SoftCheckboxState.on => SoftCheckboxState.off,
    };
  });

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    void toggleEnd() => setState(() => _endChecked = !_endChecked);
    void toggleStart() => setState(() => _startChecked = !_startChecked);
    return _DemoCard(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              SoftCheckbox.value(
                checked: _first,
                onTap: () => setState(() => _first = !_first),
              ),
              SoftCheckbox.value(
                checked: _second,
                onTap: () => setState(() => _second = !_second),
              ),
              SoftCheckbox(state: _tri, onTap: _cycle),
              const SoftCheckbox(
                state: SoftCheckboxState.off,
                onTap: null,
                enabled: false,
              ),
              const SoftCheckbox(
                state: SoftCheckboxState.on,
                onTap: null,
                enabled: false,
              ),
              const SoftCheckbox(
                state: SoftCheckboxState.indeterminate,
                onTap: null,
                enabled: false,
              ),
            ],
          ),
        ),
        _divider,
        SoftBasicComponent(
          title: '复选框',
          end: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Text(
                '$_endChecked',
                style: TextStyle(
                  fontSize: theme.textStyles.body2.fontSize,
                  color: theme.colors.onSurfaceVariantActions,
                ),
              ),
            ),
            SoftCheckbox.value(checked: _endChecked, onTap: toggleEnd),
          ],
          onTap: toggleEnd,
        ),
        _divider,
        SoftBasicComponent(
          start: Padding(
            padding: const EdgeInsetsDirectional.only(end: 5),
            child: SoftCheckbox.value(
              checked: _startChecked,
              onTap: toggleStart,
            ),
          ),
          title: '复选框',
          summary: '状态：$_startChecked',
          onTap: toggleStart,
        ),
        _divider,
        SoftBasicComponent(
          start: Padding(
            padding: const EdgeInsetsDirectional.only(end: 5),
            child: SoftCheckbox.value(
              checked: true,
              onTap: () {},
              enabled: false,
            ),
          ),
          title: '已禁用复选框',
          enabled: false,
          onTap: () {},
        ),
      ],
    );
  }
}

class _RadioButtonDemo extends StatefulWidget {
  const _RadioButtonDemo();

  @override
  State<_RadioButtonDemo> createState() => _RadioButtonDemoState();
}

class _RadioButtonDemoState extends State<_RadioButtonDemo> {
  int _selected = 0;

  Widget _option(int index, String title) {
    void select() => setState(() => _selected = index);
    final bool selected = _selected == index;
    return SoftBasicComponent(
      start: Padding(
        padding: const EdgeInsetsDirectional.only(end: 5),
        child: SoftRadioButton(selected: selected, onTap: select),
      ),
      title: title,
      summary: '已选中：$selected',
      onTap: select,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      children: <Widget>[
        _option(0, '选项 A'),
        _divider,
        _option(1, '选项 B'),
        _divider,
        _option(2, '选项 C'),
        _divider,
        SoftBasicComponent(
          start: Padding(
            padding: const EdgeInsetsDirectional.only(end: 5),
            child: SoftRadioButton(
              selected: true,
              onTap: () {},
              enabled: false,
            ),
          ),
          title: '已禁用单选按钮',
          enabled: false,
          onTap: () {},
        ),
      ],
    );
  }
}

/// A slider row: the title with the value on the end side, the slider below.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.title,
    required this.valueText,
    required this.slider,
    this.enabled = true,
  });

  final String title;
  final String valueText;
  final Widget slider;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return SoftBasicComponent(
      title: title,
      enabled: enabled,
      end: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 4),
          child: Text(
            valueText,
            style: TextStyle(
              fontSize: theme.textStyles.body2.fontSize,
              color: enabled
                  ? theme.colors.onSurfaceSecondary
                  : theme.colors.disabledOnSecondaryVariant,
            ),
          ),
        ),
      ],
      bottom: slider,
    );
  }
}

class _SliderDemo extends StatefulWidget {
  const _SliderDemo();

  @override
  State<_SliderDemo> createState() => _SliderDemoState();
}

class _SliderDemoState extends State<_SliderDemo> {
  double _normal = 0.3;
  double _steps = 100;
  double _stepsWithKeyPoints = 5;
  double _customKeyPoints = 25;
  double _secondary = 0.25;
  static const double _disabled = 0.7;

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      children: <Widget>[
        _SliderRow(
          title: '正常',
          valueText: '${(_normal * 100).toInt()}%',
          slider: SoftSlider(
            value: _normal,
            onChanged: (double v) => setState(() => _normal = v),
          ),
        ),
        _SliderRow(
          title: '步长',
          valueText: '${_steps.toInt()}/200',
          slider: SoftSlider(
            value: _steps,
            onChanged: (double v) => setState(() => _steps = v),
            max: 200,
            steps: 199,
            hapticEffect: SoftSliderHapticEffect.step,
          ),
        ),
        _SliderRow(
          title: '带关键点的步长',
          valueText: '${_stepsWithKeyPoints.toInt()}/8',
          slider: SoftSlider(
            value: _stepsWithKeyPoints,
            onChanged: (double v) => setState(() => _stepsWithKeyPoints = v),
            max: 8,
            steps: 7,
            hapticEffect: SoftSliderHapticEffect.step,
            showKeyPoints: true,
          ),
        ),
        _SliderRow(
          title: '自定义关键点',
          valueText: '${_customKeyPoints.toInt()}%',
          slider: SoftSlider(
            value: _customKeyPoints,
            onChanged: (double v) => setState(() => _customKeyPoints = v),
            max: 100,
            showKeyPoints: true,
            hapticEffect: SoftSliderHapticEffect.step,
            keyPoints: const <double>[0, 25, 50, 75, 100],
          ),
        ),
        _SliderRow(
          title: '已禁用',
          valueText: '${(_disabled * 100).toInt()}%',
          enabled: false,
          slider: SoftSlider(
            value: _disabled,
            onChanged: (_) {},
            enabled: false,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SoftSlider(
            value: _secondary,
            onChanged: (double v) => setState(() => _secondary = v),
            secondaryProgress: 0.75,
          ),
        ),
      ],
    );
  }
}

class _RangeSliderDemo extends StatefulWidget {
  const _RangeSliderDemo();

  @override
  State<_RangeSliderDemo> createState() => _RangeSliderDemoState();
}

class _RangeSliderDemoState extends State<_RangeSliderDemo> {
  SoftRangeValues _range = const SoftRangeValues(0.2, 0.8);
  SoftRangeValues _rangeSteps = const SoftRangeValues(2, 8);
  SoftRangeValues _customRange = const SoftRangeValues(20, 80);
  static const SoftRangeValues _disabled = SoftRangeValues(0.3, 0.7);

  String _percent(SoftRangeValues v) =>
      '${(v.start * 100).toInt()}% - ${(v.end * 100).toInt()}%';

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      children: <Widget>[
        _SliderRow(
          title: '范围',
          valueText: _percent(_range),
          slider: SoftRangeSlider(
            values: _range,
            onChanged: (SoftRangeValues v) => setState(() => _range = v),
          ),
        ),
        _SliderRow(
          title: '带关键点的范围',
          valueText:
              '${_rangeSteps.start.toInt()} - ${_rangeSteps.end.toInt()}',
          slider: SoftRangeSlider(
            values: _rangeSteps,
            onChanged: (SoftRangeValues v) => setState(() => _rangeSteps = v),
            max: 8,
            steps: 7,
            hapticEffect: SoftSliderHapticEffect.step,
            showKeyPoints: true,
          ),
        ),
        _SliderRow(
          title: '自定义范围点',
          valueText:
              '${_customRange.start.toInt()}% - ${_customRange.end.toInt()}%',
          slider: SoftRangeSlider(
            values: _customRange,
            onChanged: (SoftRangeValues v) => setState(() => _customRange = v),
            max: 100,
            showKeyPoints: true,
            hapticEffect: SoftSliderHapticEffect.step,
            keyPoints: const <double>[0, 20, 40, 60, 80, 100],
          ),
        ),
        _SliderRow(
          title: '已禁用',
          valueText: _percent(_disabled),
          enabled: false,
          slider: SoftRangeSlider(
            values: _disabled,
            onChanged: (_) {},
            enabled: false,
          ),
        ),
      ],
    );
  }
}
