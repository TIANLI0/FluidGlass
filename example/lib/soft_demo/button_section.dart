import 'dart:async';

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

/// The buttons and chips of the soft family, laid out like the reference
/// gallery: text buttons in every colour and size, loading buttons, icon
/// buttons, a floating action button and a card of chip groups.
class SoftDemoButtonSection extends StatefulWidget {
  const SoftDemoButtonSection({super.key});

  @override
  State<SoftDemoButtonSection> createState() => _SoftDemoButtonSectionState();
}

class _SoftDemoButtonSectionState extends State<SoftDemoButtonSection> {
  int _cancelClicks = 0;
  int _submitClicks = 0;
  int _fabClicks = 0;
  bool _dotsLoading = false;
  bool _textLoading = false;
  bool _holdDown = false;
  Timer? _dotsTimer;
  Timer? _textTimer;

  bool _recommended = true;
  bool _nearby = false;
  bool _popular = false;
  bool _dismissibleVisible = true;
  int _selectedIndex = 0;

  @override
  void dispose() {
    _dotsTimer?.cancel();
    _textTimer?.cancel();
    super.dispose();
  }

  void _loadDots() {
    setState(() => _dotsLoading = true);
    _dotsTimer?.cancel();
    _dotsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _dotsLoading = false);
    });
  }

  void _loadText() {
    setState(() => _textLoading = true);
    _textTimer?.cancel();
    _textTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _textLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SoftSmallTitle('按钮'),
        _pair(
          SoftTextButton(
            text: _cancelClicks == 0 ? '取消' : 'Click: $_cancelClicks',
            onPressed: () => setState(() => _cancelClicks++),
          ),
          SoftTextButton(
            text: _submitClicks == 0 ? '提交' : 'Click: $_submitClicks',
            variant: SoftButtonVariant.primary,
            onPressed: () => setState(() => _submitClicks++),
          ),
        ),
        _pair(
          SoftTextButton(text: '已禁用', enabled: false, onPressed: () {}),
          SoftTextButton(
            text: '已禁用',
            enabled: false,
            variant: SoftButtonVariant.primary,
            onPressed: () {},
          ),
        ),
        _pair(
          SoftTextButton(
            text: '无边框',
            variant: SoftButtonVariant.borderless,
            onPressed: () {},
          ),
          SoftTextButton(
            text: '已禁用',
            enabled: false,
            variant: SoftButtonVariant.borderless,
            onPressed: () {},
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              SoftTextButton(
                text: 'Small',
                size: SoftButtonSize.small,
                textStyle: theme.textStyles.body2.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                onPressed: () {},
              ),
              SoftTextButton(
                text: 'Small Primary',
                size: SoftButtonSize.small,
                variant: SoftButtonVariant.primary,
                textStyle: theme.textStyles.body2.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                onPressed: () {},
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              SoftTextButton(
                text: 'Tiny',
                size: SoftButtonSize.tiny,
                onPressed: () {},
              ),
              SoftTextButton(
                text: 'Tiny Primary',
                size: SoftButtonSize.tiny,
                variant: SoftButtonVariant.primary,
                onPressed: () {},
              ),
            ],
          ),
        ),
        const SoftSmallTitle('加载中按钮'),
        _pair(
          SoftLoadingButton(
            text: '下载',
            loading: _dotsLoading,
            variant: SoftButtonVariant.primary,
            onPressed: _loadDots,
          ),
          SoftLoadingButton(
            text: '登录',
            loadingText: '登录中',
            loading: _textLoading,
            onPressed: _loadText,
          ),
        ),
        const SoftSmallTitle('图标按钮'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: <Widget>[
              SoftIconButton(
                semanticLabel: '搜索',
                onPressed: () {},
                child: Icon(
                  Icons.search_rounded,
                  color: theme.colors.onSurface,
                ),
              ),
              SoftIconButton(
                semanticLabel: '分享',
                backgroundColor: theme.colors.secondaryVariant,
                onPressed: () {},
                child: Icon(
                  Icons.share_outlined,
                  color: theme.colors.onSurface,
                ),
              ),
              SoftIconButton(
                semanticLabel: '更多',
                holdDown: _holdDown,
                onPressed: () => setState(() => _holdDown = !_holdDown),
                child: Icon(
                  Icons.more_horiz_rounded,
                  color: theme.colors.onSurface,
                ),
              ),
              SoftIconButton(
                semanticLabel: '设置',
                enabled: false,
                onPressed: () {},
                child: Icon(
                  Icons.settings_outlined,
                  color: theme.colors.disabledOnSurface,
                ),
              ),
              const Spacer(),
              SoftFloatingActionButton(
                semanticLabel: '添加',
                contentColor: theme.colors.onPrimary,
                onPressed: () => setState(() => _fabClicks++),
                child: _fabClicks == 0
                    ? const Icon(Icons.add_rounded, size: 28)
                    : Text('$_fabClicks'),
              ),
            ],
          ),
        ),
        const SoftSmallTitle('标签片'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _chips(<Widget>[
                  SoftChip(
                    selected: _recommended,
                    label: '推荐',
                    icon: const Icon(Icons.check_rounded),
                    onPressed: () =>
                        setState(() => _recommended = !_recommended),
                  ),
                  SoftChip(
                    selected: _nearby,
                    label: '附近',
                    onPressed: () => setState(() => _nearby = !_nearby),
                  ),
                  SoftChip(
                    selected: _popular,
                    label: '热门',
                    onPressed: () => setState(() => _popular = !_popular),
                  ),
                  if (_dismissibleVisible)
                    SoftChip(
                      selected: false,
                      label: '可关闭',
                      dismissSemanticLabel: '关闭',
                      onPressed: () {},
                      onDismiss: () =>
                          setState(() => _dismissibleVisible = false),
                    ),
                ]),
                const SoftDivider(indent: 16, endIndent: 16),
                _chips(<Widget>[
                  for (final (int i, String label) in const <String>[
                    '全部',
                    '照片',
                    '视频',
                    '文档',
                  ].indexed)
                    SoftChip(
                      selected: _selectedIndex == i,
                      label: label,
                      onPressed: () => setState(() => _selectedIndex = i),
                    ),
                ]),
                const SoftDivider(indent: 16, endIndent: 16),
                _chips(<Widget>[
                  SoftChip(
                    selected: false,
                    enabled: false,
                    label: '已禁用',
                    onPressed: () {},
                  ),
                  SoftChip(
                    selected: true,
                    enabled: false,
                    label: '已禁用已选中',
                    onPressed: () {},
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _pair(Widget start, Widget end) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: <Widget>[
          Expanded(child: start),
          const SizedBox(width: 12),
          Expanded(child: end),
        ],
      ),
    );
  }

  Widget _chips(List<Widget> chips) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }
}
