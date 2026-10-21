import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const List<String> _history = <String>[
  '无线耳机',
  '屏幕保护膜',
  'USB-C 扩展坞',
  '笔记本支架',
  '机械键盘',
  '便携充电器',
  '摄像头',
  '显示器支架',
  '台灯',
];

/// The input group of the soft family laid out like the reference gallery:
/// line fields, fields on a card, rectangle fields with a floating label,
/// the card inputs and the search bar.
class SoftDemoInputSection extends StatefulWidget {
  const SoftDemoInputSection({super.key});

  @override
  State<SoftDemoInputSection> createState() => _SoftDemoInputSectionState();
}

class _SoftDemoInputSectionState extends State<SoftDemoInputSection> {
  final TextEditingController _digits = TextEditingController();
  final TextEditingController _nickname = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _query = TextEditingController();
  final TextEditingController _disabled = TextEditingController(text: '已禁用');
  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    for (final TextEditingController c in <TextEditingController>[
      _digits,
      _nickname,
      _password,
      _query,
    ]) {
      c.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _digits.dispose();
    _nickname.dispose();
    _password.dispose();
    _query.dispose();
    _disabled.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  static const EdgeInsets _row = EdgeInsets.fromLTRB(16, 0, 16, 12);

  @override
  Widget build(BuildContext context) {
    final String digits = _digits.text;
    final bool digitsError =
        digits.isNotEmpty && !RegExp(r'^\d+$').hasMatch(digits);
    final String password = _password.text;
    final String query = _query.text.trim();
    final List<String> results = query.isEmpty
        ? _history
        : _history.where((String h) => h.contains(query)).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SoftSmallTitle('搜索栏'),
        SoftSearchBar(
          expanded: _searchExpanded,
          onExpandedChange: (bool v) => setState(() => _searchExpanded = v),
          inputField: SoftSearchField(
            controller: _query,
            label: '搜索',
            expanded: _searchExpanded,
            onExpandedChange: (bool v) => setState(() => _searchExpanded = v),
            searchSemanticLabel: '搜索',
            clearButtonSemanticLabel: '清除',
          ),
          outsideEndAction: SoftSearchBarCancelAction(
            label: '取消',
            onTap: () => setState(() => _searchExpanded = false),
          ),
          content: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: SoftCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int i = 0; i < results.length; i++)
                    SoftBasicComponent(
                      title: results[i],
                      position: SoftCardListPosition.of(i, results.length),
                      onTap: () {
                        _query.text = results[i];
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: SoftSearchField(
            label: '搜索设置项',
            enabled: false,
            expanded: false,
            onExpandedChange: _ignore,
          ),
        ),
        const SoftSmallTitle('输入框（线框，设置对话框样式）'),
        const Padding(
          padding: _row,
          child: SoftTextField(
            label: '设备名称',
            showClearButton: true,
            textInputAction: TextInputAction.done,
            clearButtonSemanticLabel: '清除',
          ),
        ),
        const Padding(
          padding: _row,
          child: SoftTextField(
            label: '密码',
            showPasswordToggle: true,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            showPasswordSemanticLabel: '显示密码',
            hidePasswordSemanticLabel: '隐藏密码',
          ),
        ),
        const Padding(
          padding: _row,
          child: SoftTextField(
            label: '最多 10 个字符',
            maxCount: 10,
            textInputAction: TextInputAction.done,
          ),
        ),
        Padding(
          padding: _row,
          child: SoftTextField(
            controller: _digits,
            label: '仅数字（错误状态）',
            isError: digitsError,
            textInputAction: TextInputAction.done,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SoftTextField(
            controller: _disabled,
            label: '已禁用',
            enabled: false,
          ),
        ),
        const SoftSmallTitle('输入框（卡片内，设置项样式）'),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SoftCard(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: SoftTextField(
                    label: '仅焦点线',
                    justShowFocusLine: true,
                    textInputAction: TextInputAction.done,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: SoftTextField(
                    label: '无装饰（卡片输入）',
                    mode: SoftTextFieldMode.none,
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SoftSmallTitle('输入框（矩形与浮动标签）'),
        const Padding(
          padding: _row,
          child: SoftTextField(
            label: '矩形（仅描边）',
            mode: SoftTextFieldMode.rectangle,
            textInputAction: TextInputAction.done,
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SoftTextField(
            label: '浮动标签',
            useLabelAsPlaceholder: false,
            mode: SoftTextFieldMode.rectangle,
            textInputAction: TextInputAction.done,
          ),
        ),
        const SoftSmallTitle('输入视图（卡片单输入）'),
        Padding(
          padding: _row,
          child: SoftInputView(
            controller: _nickname,
            title: '昵称',
            label: '输入昵称',
            showCount: true,
            maxCount: 10,
            showClearButton: true,
            errorMessage: _nickname.text.contains(' ') ? '昵称不能包含空格' : '',
            textInputAction: TextInputAction.done,
            clearButtonSemanticLabel: '清除',
          ),
        ),
        Padding(
          padding: _row,
          child: SoftInputView(
            controller: _password,
            title: '密码',
            label: '至少 8 个字符',
            showPasswordToggle: true,
            errorMessage: password.isNotEmpty && password.length < 8
                ? '密码太短'
                : '',
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            showPasswordSemanticLabel: '显示密码',
            hidePasswordSemanticLabel: '隐藏密码',
          ),
        ),
        const SoftSmallTitle('输入视图（卡片多输入）'),
        const Padding(
          padding: _row,
          child: SoftInputView(
            label: '签名（多行）',
            showCount: true,
            maxCount: 100,
            singleLine: false,
          ),
        ),
      ],
    );
  }
}

void _ignore(bool _) {}
