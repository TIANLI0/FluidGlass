import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

/// The snackbar, top tips, tooltip, progress indicator, page indicator and
/// empty state sections of the reference gallery: a card of each, with every
/// variant it shows.
class SoftDemoFeedbackSection extends StatelessWidget {
  const SoftDemoFeedbackSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SoftSmallTitle('提示条'),
        _SnackbarDemo(),
        SoftSmallTitle('顶部提示'),
        _TopTipsDemo(),
        SoftSmallTitle('顶部提示样式'),
        _TopTipsStylesDemo(),
        SoftSmallTitle('提示气泡'),
        _TooltipDemo(),
        SoftSmallTitle('进度指示器'),
        _ProgressDemo(),
        SoftSmallTitle('页面指示器'),
        _PageIndicatorDemo(),
        SoftSmallTitle('空状态'),
        _EmptyStateDemo(),
      ],
    );
  }
}

/// A card inset 16 from the sides with 16 below, as each gallery card sits.
class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SoftCard(child: child),
    );
  }
}

/// The gallery's grey text button.
class _DemoButton extends StatelessWidget {
  const _DemoButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final SoftColors colors = theme.colors;
    return SoftPressable(
      onTap: onTap,
      feedback: SoftPressFeedback.sink,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: ShapeDecoration(
          color: primary ? colors.primary : colors.secondaryVariant,
          shape: SoftSquircleBorder.all(16, smooth: theme.smoothCorners),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textStyles.button.copyWith(
            color: primary ? colors.onPrimary : colors.onSecondaryVariant,
          ),
        ),
      ),
    );
  }
}

Widget _pair(Widget a, Widget b) => Row(
  children: <Widget>[
    Expanded(child: a),
    const SizedBox(width: 12),
    Expanded(child: b),
  ],
);

class _SnackbarDemo extends StatefulWidget {
  const _SnackbarDemo();

  @override
  State<_SnackbarDemo> createState() => _SnackbarDemoState();
}

class _SnackbarDemoState extends State<_SnackbarDemo> {
  String _actionLabel = '操作';

  SoftSnackbarHostState get _host => softOverlaySnackbarHost(context);

  Future<void> _withAction() async {
    setState(() => _actionLabel = '操作：有效');
    final SoftSnackbarResult result = await _host.showSnackbar(
      message: '这条消息带一个操作',
      actionLabel: '撤销',
    );
    if (!mounted) return;
    setState(
      () => _actionLabel = result == SoftSnackbarResult.actionPerformed
          ? '操作：撤销'
          : '操作：已过期',
    );
  }

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          spacing: 12,
          children: <Widget>[
            _pair(
              _DemoButton(
                label: '关闭最早',
                onTap: () => _host.oldestSnackbarData?.dismiss(),
              ),
              _DemoButton(
                label: '关闭最新',
                onTap: () => _host.newestSnackbarData?.dismiss(),
              ),
            ),
            _pair(
              _DemoButton(
                label: '短（4 秒）',
                onTap: () => _host.showSnackbar(message: '这是一条短消息'),
              ),
              _DemoButton(
                label: '长（10 秒）',
                onTap: () => _host.showSnackbar(
                  message: '这是一条较长的消息，用于展示更多文本内容',
                  duration: SoftSnackbarDuration.long,
                ),
              ),
            ),
            _pair(
              _DemoButton(
                label: '自定义（2 秒）',
                onTap: () => _host.showSnackbar(
                  message: '这条消息会显示 2 秒',
                  duration: const SoftSnackbarDuration.custom(
                    Duration(seconds: 2),
                  ),
                ),
              ),
              _DemoButton(
                label: _actionLabel,
                primary: true,
                onTap: _withAction,
              ),
            ),
            _pair(
              _DemoButton(
                label: '可关闭',
                onTap: () => _host.showSnackbar(
                  message: '这条消息可通过关闭按钮移除',
                  withDismissAction: true,
                  duration: SoftSnackbarDuration.long,
                ),
              ),
              _DemoButton(
                label: '常驻',
                onTap: () => _host.showSnackbar(
                  message: '常驻消息，手动关闭',
                  withDismissAction: true,
                  duration: SoftSnackbarDuration.indefinite,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopTipsDemo extends StatefulWidget {
  const _TopTipsDemo();

  @override
  State<_TopTipsDemo> createState() => _TopTipsDemoState();
}

class _TopTipsDemoState extends State<_TopTipsDemo> {
  bool _closable = true;

  @override
  Widget build(BuildContext context) {
    final SoftColors colors = SoftTheme.colorsOf(context);
    return _DemoCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: <Widget>[
            SoftTopTips(
              text: '带起始图标的可关闭提示',
              visible: _closable,
              startIcon: Icon(
                Icons.search,
                size: 24,
                color: colors.onSurfaceSecondary,
              ),
              onClose: () => setState(() => _closable = false),
            ),
            SoftTopTips(text: '有新的安全更新', actionText: '更新', onAction: () {}),
            SoftTopTips(
              text: '这条较长的消息用于展示操作标签在文字冲突时如何换到单独一行',
              actionText: '开启',
              onAction: () {},
            ),
            if (!_closable)
              _DemoButton(
                label: '再次显示可关闭提示',
                onTap: () => setState(() => _closable = true),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopTipsStylesDemo extends StatefulWidget {
  const _TopTipsStylesDemo();

  @override
  State<_TopTipsStylesDemo> createState() => _TopTipsStylesDemoState();
}

class _TopTipsStylesDemoState extends State<_TopTipsStylesDemo> {
  bool _custom = true;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return _DemoCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: <Widget>[
            SoftTopTips(
              text: '白色提示，填充卡片色',
              title: '白色背景',
              background: SoftTopTipsBackground.white,
              actionText: '知道了',
              onAction: () {},
            ),
            SoftTopTips(
              text: '灰色提示，填充容器色',
              background: SoftTopTipsBackground.gray,
              onClose: () {},
            ),
            SoftTopTips(
              visible: _custom,
              title: '自定义内容',
              startIcon: Icon(
                Icons.search,
                size: 36,
                color: theme.colors.onSurfaceSecondary,
              ),
              actionText: '知道了',
              onAction: () => setState(() => _custom = false),
              onClose: () => setState(() => _custom = false),
              content: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: '消息正文是一个自定义插槽。',
                      style: TextStyle(
                        color: theme.colors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const TextSpan(text: ' 保持简短。'),
                  ],
                ),
                style: theme.textStyles.footnote1.copyWith(
                  color: theme.colors.onSurfaceSecondary,
                ),
              ),
            ),
            if (!_custom)
              _DemoButton(
                label: '再次显示',
                onTap: () => setState(() => _custom = true),
              ),
          ],
        ),
      ),
    );
  }
}

class _TooltipDemo extends StatelessWidget {
  const _TooltipDemo();

  @override
  Widget build(BuildContext context) {
    final SoftColors colors = SoftTheme.colorsOf(context);
    Widget iconButton(IconData icon) => SoftPressable(
      onTap: () {},
      borderRadius: BorderRadius.circular(20),
      child: SizedBox.square(
        dimension: 40,
        child: Icon(icon, size: 24, color: colors.onSurface),
      ),
    );
    return _DemoCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            SoftTooltip(message: '编辑', child: iconButton(Icons.edit_outlined)),
            SoftTooltip(
              message: '编辑',
              showCaret: true,
              position: SoftTooltipPosition.above,
              child: iconButton(Icons.edit_note),
            ),
            SoftRichTooltipBox(
              title: '富文本气泡',
              text: '富文本气泡包含标题、辅助文字和可选操作。移到气泡上可执行操作，点击外部可关闭。',
              actionText: '知道了',
              onAction: () {},
              child: iconButton(Icons.info_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDemo extends StatefulWidget {
  const _ProgressDemo();

  @override
  State<_ProgressDemo> createState() => _ProgressDemoState();
}

class _ProgressDemoState extends State<_ProgressDemo>
    with SingleTickerProviderStateMixin {
  // The gallery's ping-pong value, 0 → 1 → 0 every two seconds.
  late final AnimationController _value = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  static const List<double?> _values = <double?>[0, 0.25, 0.5, 0.75, 1, null];

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> eased = CurvedAnimation(
      parent: _value,
      curve: Curves.easeInOut,
    );
    return _DemoCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: <Widget>[
            AnimatedBuilder(
              animation: eased,
              builder: (BuildContext context, Widget? child) =>
                  SoftLinearProgressIndicator(progress: eased.value),
            ),
            for (final double? value in _values)
              SoftLinearProgressIndicator(progress: value),
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                AnimatedBuilder(
                  animation: eased,
                  builder: (BuildContext context, Widget? child) =>
                      SoftCircularProgressIndicator(progress: eased.value),
                ),
                for (final double? value in _values)
                  SoftCircularProgressIndicator(progress: value),
                const SoftCircularProgressIndicator(
                  state: SoftCircularProgressState.error,
                ),
                const SoftCircularProgressIndicator(
                  state: SoftCircularProgressState.paused,
                ),
                const SoftInfiniteProgressIndicator(),
                const SoftRotatingProgressIndicator(),
                const SoftRotatingProgressIndicator.small(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIndicatorDemo extends StatelessWidget {
  const _PageIndicatorDemo();

  @override
  Widget build(BuildContext context) {
    return const _DemoCard(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          spacing: 16,
          children: <Widget>[
            SoftPageIndicator(count: 3, currentIndex: 1),
            SoftPageIndicator(count: 5, currentIndex: 0),
            SoftPageIndicator(count: 8, currentIndex: 6),
            SoftPageIndicator(count: 0, currentIndex: 0),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateDemo extends StatelessWidget {
  const _EmptyStateDemo();

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: SoftEmptyState(
              title: '无结果',
              subtitle: '换个关键词试试',
              size: SoftEmptyStateSize.medium,
            ),
          ),
          const SoftDivider(indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SoftEmptyState(
              title: '这里还什么都没有',
              subtitle: '你添加的内容会显示在这里',
              actionText: '添加',
              onAction: () {},
            ),
          ),
        ],
      ),
    );
  }
}
