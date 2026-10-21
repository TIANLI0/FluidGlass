import 'dart:async';

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/widgets.dart';

/// The dialogs of the soft family, laid out like the reference gallery: a
/// card of rows, each opening one dialog or button-bar variant. A row stays
/// pressed while its dialog is open.
class SoftDemoDialogSection extends StatefulWidget {
  const SoftDemoDialogSection({super.key});

  @override
  State<SoftDemoDialogSection> createState() => _SoftDemoDialogSectionState();
}

class _SoftDemoDialogSectionState extends State<SoftDemoDialogSection> {
  /// The row whose dialog is open.
  int? _holding;
  final ValueNotifier<double?> _progress = ValueNotifier<double?>(null);

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _hold(int row) => setState(() => _holding = row);

  void _release() {
    if (mounted) setState(() => _holding = null);
  }

  void _dialog() {
    _hold(0);
    showSoftDialog<void>(
      context: context,
      title: '对话框',
      summary: '弹出层内的对话框组件。',
      onDismissFinished: _release,
      builder: (BuildContext context) => SoftDialogButtonBar(
        negative: SoftDialogAction(
          label: '取消',
          onPressed: () => dismissSoftDialog<void>(context),
        ),
        positive: SoftDialogAction(
          label: '确定',
          onPressed: () => dismissSoftDialog<void>(context),
        ),
      ),
    );
  }

  void _centered() {
    _hold(1);
    showSoftDialog<void>(
      context: context,
      title: '居中对话框',
      summary: '大屏上对话框居中显示，以缩放与淡入淡出代替自底部滑入。',
      largeScreen: true,
      onDismissFinished: _release,
      builder: (BuildContext context) => SoftDialogButtonBar(
        negative: SoftDialogAction(
          label: '取消',
          onPressed: () => dismissSoftDialog<void>(context),
        ),
        positive: SoftDialogAction(
          label: '确定',
          onPressed: () => dismissSoftDialog<void>(context),
        ),
      ),
    );
  }

  Future<void> _loading() async {
    _hold(2);
    bool open = true;
    unawaited(
      showSoftLoadingDialog(
        context: context,
        text: '加载中…',
        dismissible: true,
        onDismissFinished: _release,
      ).then((_) => open = false),
    );
    // Dismiss itself after a while, like a finished task would.
    await Future<void>.delayed(const Duration(seconds: 3));
    if (open && mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  void _stacked() {
    _hold(3);
    showSoftDialog<void>(
      context: context,
      title: '删除备份',
      summary: '下方按钮标签放不下，因此按钮栏改为纵向堆叠。',
      onDismissFinished: _release,
      builder: (BuildContext context) => SoftDialogButtonBar(
        negative: SoftDialogAction(
          label: '暂不',
          onPressed: () => dismissSoftDialog<void>(context),
        ),
        positive: SoftDialogAction(
          label: '删除备份和本地副本，同时清除所有同步设备上的记录',
          onPressed: () => dismissSoftDialog<void>(context),
        ),
      ),
    );
  }

  void _recommended() {
    _hold(4);
    showSoftDialog<void>(
      context: context,
      title: '安装更新',
      summary: '下方的积极操作是操作栏的推荐按钮。',
      onDismissFinished: _release,
      builder: (BuildContext context) => SoftDialogButtonBar(
        negative: SoftDialogAction(
          label: '稍后',
          onPressed: () => dismissSoftDialog<void>(context),
        ),
        positive: SoftDialogAction(
          label: '安装',
          recommended: true,
          onPressed: () => dismissSoftDialog<void>(context),
        ),
      ),
    );
  }

  void _threeButtons() {
    _hold(5);
    showSoftDialog<void>(
      context: context,
      title: '保存更改',
      summary: '三个操作时按钮栏总是纵向堆叠。',
      onDismissFinished: _release,
      builder: (BuildContext context) => SoftDialogButtonBar(
        negative: SoftDialogAction(
          label: '取消',
          onPressed: () => dismissSoftDialog<void>(context),
        ),
        neutral: SoftDialogAction(
          label: '不保存',
          destructive: true,
          onPressed: () => dismissSoftDialog<void>(context),
        ),
        positive: SoftDialogAction(
          label: '保存',
          onPressed: () => dismissSoftDialog<void>(context),
        ),
      ),
    );
  }

  void _alert() {
    _hold(6);
    final SoftThemeData theme = SoftTheme.of(context);
    showSoftAlertDialog(
      context: context,
      title: '删除这个备份？',
      summary: '备份将从云端和所有已同步的设备上移除。',
      confirmText: '删除',
      cancelText: '取消',
      destructive: true,
      onDismissFinished: _release,
      content: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: SoftDialogDefaults.insideMargin.width,
        ),
        child: Text(
          '此操作无法撤销。',
          textAlign: TextAlign.center,
          style: theme.textStyles.body2.copyWith(
            color: theme.colors.onSurfaceVariantSummary,
          ),
        ),
      ),
    );
  }

  Future<void> _progressDialog() async {
    _hold(7);
    bool open = true;
    _progress.value = null;
    unawaited(
      showSoftProgressDialog(
        context: context,
        progress: _progress,
        textBuilder: (double? value) => value == null ? '连接中…' : '下载中…',
        dismissible: true,
        onDismissFinished: _release,
      ).then((_) => open = false),
    );
    // Indeterminate first, then determinate, like a download that learns
    // its size once the request is accepted.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    for (int step = 0; step < 40 && open; step++) {
      _progress.value = step / 40;
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    if (!open) return;
    _progress.value = 1;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (open && mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final List<(String, String, VoidCallback)> rows =
        <(String, String, VoidCallback)>[
          ('对话框', '点击显示对话框', _dialog),
          ('居中对话框', '大屏呈现：缩放淡入，居中显示', _centered),
          ('加载对话框', '点击显示加载对话框', _loading),
          ('堆叠按钮栏', '标签过长时按钮栏转为纵向堆叠', _stacked),
          ('推荐按钮栏', '一个操作被高亮为推荐按钮', _recommended),
          ('三按钮栏', '中性操作与破坏性样式', _threeButtons),
          ('警告对话框', '居中的警示对话框，带确定 / 取消按钮', _alert),
          ('进度对话框', '横向进度对话框，先不定后确定', _progressDialog),
        ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SoftCard(
        child: Column(
          children: <Widget>[
            for (int i = 0; i < rows.length; i++) ...<Widget>[
              if (i > 0) const SoftDivider(indent: 16, endIndent: 16),
              SoftBasicComponent(
                title: rows[i].$1,
                summary: rows[i].$2,
                position: SoftCardListPosition.of(i, rows.length),
                holdDown: _holding == i,
                onTap: rows[i].$3,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
