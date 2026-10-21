import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

/// The bottom sheet section of the soft gallery: two rows, one opening the
/// declarative [SoftBottomSheet] (O) and one calling [showSoftBottomSheet]
/// (W), each sheet holding the reference demo's behaviour settings and
/// controls.
class SoftDemoSheetSection extends StatefulWidget {
  const SoftDemoSheetSection({super.key});

  @override
  State<SoftDemoSheetSection> createState() => _SoftDemoSheetSectionState();
}

class _SoftDemoSheetSectionState extends State<SoftDemoSheetSection> {
  static const List<String> _options = <String>['选项 1', '选项 2'];

  bool _showOverlay = false;
  bool _overlayHoldDown = false;
  bool _windowHoldDown = false;

  final ValueNotifier<bool> _overlayAllowDismiss = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _overlayNestedScroll = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _windowAllowDismiss = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _windowNestedScroll = ValueNotifier<bool>(true);
  final ValueNotifier<int> _option = ValueNotifier<int>(0);
  final ValueNotifier<bool> _switch = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _overlayAllowDismiss.dispose();
    _overlayNestedScroll.dispose();
    _windowAllowDismiss.dispose();
    _windowNestedScroll.dispose();
    _option.dispose();
    _switch.dispose();
    super.dispose();
  }

  void _closeOverlay() => setState(() => _showOverlay = false);

  Future<void> _openWindow() async {
    setState(() => _windowHoldDown = true);
    // Read when the sheet opens; toggling them inside applies next time.
    await showSoftBottomSheet<void>(
      context: context,
      title: '底部面板（W）',
      allowDismiss: _windowAllowDismiss.value,
      enableNestedScroll: _windowNestedScroll.value,
      barrierLabel: '关闭',
      startAction: Builder(
        builder: (BuildContext context) => _DemoIconButton(
          icon: Icons.close_rounded,
          label: '取消',
          onTap: () => SoftBottomSheetScope.dismissOf(context)?.call(),
        ),
      ),
      endAction: Builder(
        builder: (BuildContext context) => _DemoIconButton(
          icon: Icons.check_rounded,
          label: '确定',
          onTap: () => SoftBottomSheetScope.dismissOf(context)?.call(),
        ),
      ),
      builder: (BuildContext context) => _SheetDemoContent(
        allowDismiss: _windowAllowDismiss,
        nestedScroll: _windowNestedScroll,
        option: _option,
        options: _options,
        dropdownTitle: '下拉项（W）',
        switchValue: _switch,
      ),
    );
    if (mounted) setState(() => _windowHoldDown = false);
  }

  @override
  Widget build(BuildContext context) {
    final SoftColors colors = SoftTheme.of(context).colors;
    final Widget arrow = Icon(
      Icons.chevron_right_rounded,
      size: 20,
      color: colors.onSurfaceVariantActions,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: SoftCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SoftBasicComponent(
                  title: '底部面板（O）',
                  summary: '点击显示 OverlayBottomSheet',
                  end: <Widget>[arrow],
                  position: SoftCardListPosition.head,
                  holdDown: _overlayHoldDown,
                  onTap: () => setState(() {
                    _showOverlay = true;
                    _overlayHoldDown = true;
                  }),
                ),
                const SoftDivider(indent: 16, endIndent: 16),
                SoftBasicComponent(
                  title: '底部面板（W）',
                  summary: '点击显示 WindowBottomSheet',
                  end: <Widget>[arrow],
                  position: SoftCardListPosition.tail,
                  holdDown: _windowHoldDown,
                  onTap: _openWindow,
                ),
              ],
            ),
          ),
        ),
        ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            _overlayAllowDismiss,
            _overlayNestedScroll,
          ]),
          builder: (BuildContext context, Widget? content) => SoftBottomSheet(
            show: _showOverlay,
            title: '底部面板（O）',
            allowDismiss: _overlayAllowDismiss.value,
            enableNestedScroll: _overlayNestedScroll.value,
            barrierLabel: '关闭',
            onDismissRequest: _closeOverlay,
            onDismissFinished: () => setState(() => _overlayHoldDown = false),
            startAction: _DemoIconButton(
              icon: Icons.close_rounded,
              label: '取消',
              onTap: _closeOverlay,
            ),
            endAction: _DemoIconButton(
              icon: Icons.check_rounded,
              label: '确定',
              onTap: _closeOverlay,
            ),
            child: content!,
          ),
          child: _SheetDemoContent(
            allowDismiss: _overlayAllowDismiss,
            nestedScroll: _overlayNestedScroll,
            option: _option,
            options: _options,
            dropdownTitle: '下拉项（O）',
            switchValue: _switch,
          ),
        ),
      ],
    );
  }
}

/// The reference demo's sheet body: behaviour settings, an input and a
/// card of preferences, ending above the bottom system inset.
class _SheetDemoContent extends StatefulWidget {
  const _SheetDemoContent({
    required this.allowDismiss,
    required this.nestedScroll,
    required this.option,
    required this.options,
    required this.dropdownTitle,
    required this.switchValue,
  });

  final ValueNotifier<bool> allowDismiss;
  final ValueNotifier<bool> nestedScroll;
  final ValueNotifier<int> option;
  final List<String> options;
  final String dropdownTitle;
  final ValueNotifier<bool> switchValue;

  @override
  State<_SheetDemoContent> createState() => _SheetDemoContentState();
}

class _SheetDemoContentState extends State<_SheetDemoContent> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Widget _switchRow({
    required String title,
    String? summary,
    required ValueNotifier<bool> value,
    SoftCardListPosition position = SoftCardListPosition.none,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: value,
      builder: (BuildContext context, bool on, Widget? _) => SoftBasicComponent(
        title: title,
        summary: summary,
        position: position,
        end: <Widget>[_DemoSwitch(value: on)],
        onTap: () => value.value = !on,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final SoftColors colors = theme.colors;
    final Color cardColor = colors.secondaryContainer;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SoftSmallTitle(
            '行为设置',
            insideMargin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          SoftCard(
            color: cardColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _switchRow(
                  title: '允许关闭',
                  summary: '拖动或返回关闭',
                  value: widget.allowDismiss,
                  position: SoftCardListPosition.head,
                ),
                const SoftDivider(indent: 16, endIndent: 16),
                _switchRow(
                  title: '启用嵌套滚动',
                  summary: '滚动内容与拖动面板',
                  value: widget.nestedScroll,
                  position: SoftCardListPosition.tail,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            color: cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Stack(
              children: <Widget>[
                ListenableBuilder(
                  listenable: _text,
                  builder: (BuildContext context, Widget? _) =>
                      _text.text.isEmpty
                      ? Text(
                          '输入框',
                          style: theme.textStyles.body1.copyWith(
                            color: colors.onSurfaceVariantSummary,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                EditableText(
                  controller: _text,
                  focusNode: _focus,
                  style: theme.textStyles.body1.copyWith(
                    color: colors.onBackground,
                  ),
                  cursorColor: colors.primary,
                  backgroundCursorColor: colors.onSurfaceVariantSummary,
                  selectionColor: colors.tertiaryContainer,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            color: cardColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ValueListenableBuilder<int>(
                  valueListenable: widget.option,
                  builder: (BuildContext context, int index, Widget? _) =>
                      SoftBasicComponent(
                        title: widget.dropdownTitle,
                        position: SoftCardListPosition.head,
                        end: <Widget>[
                          Text(
                            widget.options[index],
                            style: theme.textStyles.body2.copyWith(
                              color: colors.onSurfaceVariantSummary,
                            ),
                          ),
                        ],
                        onTap: () => widget.option.value =
                            (index + 1) % widget.options.length,
                      ),
                ),
                const SoftDivider(indent: 16, endIndent: 16),
                _switchRow(
                  title: '开关项',
                  value: widget.switchValue,
                  position: SoftCardListPosition.tail,
                ),
              ],
            ),
          ),
          SizedBox(height: 12 + MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

/// A 48 round icon button for the title row's actions.
class _DemoIconButton extends StatelessWidget {
  const _DemoIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: SoftPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox.square(
          dimension: 48,
          child: Icon(
            icon,
            size: 24,
            color: SoftTheme.of(context).colors.onBackground,
          ),
        ),
      ),
    );
  }
}

/// A plain on/off indicator for the demo rows.
class _DemoSwitch extends StatelessWidget {
  const _DemoSwitch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final SoftColors colors = SoftTheme.of(context).colors;
    return SizedBox(
      width: 40,
      height: 24,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: value ? colors.primary : colors.secondary,
          shape: const StadiumBorder(),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: SoftMotion.inEase,
          alignment: value
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: const Padding(
            padding: EdgeInsets.all(3),
            child: SizedBox.square(
              dimension: 18,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: Color(0xFFFFFFFF),
                  shape: CircleBorder(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
