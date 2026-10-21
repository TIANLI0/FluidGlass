import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart'
    show AdaptiveTextSelectionToolbar, Icons, SelectableText;
import 'package:flutter/widgets.dart';

/// The library pieces an app needs for its profile, device, chat and notice
/// screens.
class SoftAppComponentsPage extends StatefulWidget {
  const SoftAppComponentsPage({super.key});
  @override
  State<SoftAppComponentsPage> createState() => _SoftAppComponentsPageState();
}

class _SoftAppComponentsPageState extends State<SoftAppComponentsPage> {
  DateTime? _birthday;
  int _number = 50;
  int _refreshCount = 0;
  bool _revealed = false, _notice = true, _expanded = false, _enabled = true;
  String _status = '下拉可刷新，通知可向左滑动';

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showSoftDatePicker(
      context: context,
      initialDate: _birthday,
      lastDate: DateTime(now.year, now.month, now.day),
      title: '出生日期',
      confirmLabel: '确定',
      cancelLabel: '取消',
      yearLabel: (int value) => '$value年',
      monthLabel: (int value) => '$value月',
      dayLabel: (int value) => '$value日',
      yearSemanticLabel: '年',
      monthSemanticLabel: '月',
      daySemanticLabel: '日',
    );
    if (mounted && date != null) setState(() => _birthday = date);
  }

  Widget _card(Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: SoftCard(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return SoftPullToRefresh(
      pullLabel: '下拉刷新',
      releaseLabel: '松手刷新',
      refreshingLabel: '正在刷新',
      completeLabel: '刷新完成',
      onRefresh: () async {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted) {
          setState(() {
            _refreshCount++;
            _status = '已刷新 $_refreshCount 次';
          });
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 32,
          16,
          SoftFloatingNavigationBarDefaults.extent(context) + 24,
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text('应用组件', style: theme.textStyles.title1),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(_status, style: theme.textStyles.body2),
          ),
          const SoftSmallTitle('资料与设备设置'),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _birthday == null
                      ? '生日：尚未选择'
                      : '生日：${_birthday!.year}-${_birthday!.month}-${_birthday!.day}',
                ),
                const SizedBox(height: 12),
                SoftTextButton(text: '选择出生日期', onPressed: _pickDate),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(child: Text('数值：$_number')),
                    SizedBox(
                      width: 100,
                      child: SoftNumberPicker(
                        value: _number,
                        min: 0,
                        max: 100,
                        semanticLabel: '数值',
                        onChanged: (int value) =>
                            setState(() => _number = value),
                      ),
                    ),
                  ],
                ),
                SoftExpandableGroup(
                  expanded: _expanded,
                  onToggle: () => setState(() => _expanded = !_expanded),
                  headerBuilder: (_, bool expanded) => SizedBox(
                    height: 48,
                    child: Row(
                      children: <Widget>[
                        Expanded(child: Text(expanded ? '收起更多设置' : '展开更多设置')),
                        Icon(expanded ? Icons.expand_less : Icons.expand_more),
                      ],
                    ),
                  ),
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Expanded(child: Text('消息提醒')),
                        SoftSwitch(
                          checked: _enabled,
                          onChanged: (bool value) =>
                              setState(() => _enabled = value),
                          semanticLabel: '消息提醒',
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('展开过程中不会误触内部操作。'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SoftSmallTitle('可滑动通知'),
          if (_notice)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SoftNotificationSwipeBox(
                revealed: _revealed,
                onRevealedChanged: (bool value) =>
                    setState(() => _revealed = value),
                settingsLabel: '通知设置',
                dismissLabel: '删除通知',
                settingsIcon: const Icon(Icons.settings_outlined),
                dismissIcon: const Icon(Icons.delete_outline),
                onSettings: () => setState(() => _status = '已触发通知设置'),
                onDismiss: () => setState(() => _notice = false),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.notifications_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('有一条新消息', style: theme.textStyles.body1),
                            Text('向左滑动查看设置和删除', style: theme.textStyles.body2),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            _card(
              SoftTextButton(
                text: '恢复通知示例',
                onPressed: () => setState(() {
                  _notice = true;
                  _revealed = false;
                }),
              ),
            ),
          const SoftSmallTitle('富内容提醒'),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SoftNotificationSnackBar(
              title: '来自伙伴的消息',
              message: '通知正文可以换行，操作和关闭各自响应。',
              image: const Icon(Icons.chat_bubble_outline, size: 32),
              actionLabel: '回复',
              onAction: () => setState(() => _status = '已触发回复'),
              onClose: () => setState(() => _status = '已触发关闭'),
              closeLabel: '关闭提醒',
            ),
          ),
          const SoftSmallTitle('聊天选区菜单'),
          _card(
            SelectableText(
              '长按这段文字，可选择、复制或全选。选择手柄由 Flutter 原生处理。',
              contextMenuBuilder:
                  (BuildContext context, EditableTextState state) =>
                      SoftTextSelectionMenu(
                        anchors: state.contextMenuAnchors,
                        actions: <SoftTextSelectionAction>[
                          for (final ContextMenuButtonItem item
                              in state.contextMenuButtonItems)
                            SoftTextSelectionAction(
                              label:
                                  AdaptiveTextSelectionToolbar.getButtonLabel(
                                    context,
                                    item,
                                  ),
                              onPressed: item.onPressed,
                            ),
                        ],
                      ),
            ),
          ),
          const SoftSmallTitle('通用横向菜单'),
          _card(
            Builder(
              builder: (BuildContext anchor) => SoftTextButton(
                text: '更多操作',
                onPressed: () => showSoftHorizontalPopupMenu(
                  context: anchor,
                  items: <SoftHorizontalMenuItem>[
                    SoftHorizontalMenuItem(
                      icon: const Icon(Icons.copy),
                      label: '复制',
                      onPressed: () => setState(() => _status = '已触发复制示例'),
                    ),
                    SoftHorizontalMenuItem(
                      icon: const Icon(Icons.share_outlined),
                      label: '分享',
                      onPressed: () => setState(() => _status = '已触发分享示例'),
                    ),
                    const SoftHorizontalMenuItem(
                      icon: Icon(Icons.block),
                      label: '不可用',
                      onPressed: null,
                      enabled: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
