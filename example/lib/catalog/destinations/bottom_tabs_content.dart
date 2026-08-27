import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';
import '../flight_icon.dart';

class BottomTabsContent extends StatefulWidget {
  const BottomTabsContent({super.key});

  @override
  State<BottomTabsContent> createState() => _BottomTabsContentState();
}

class _BottomTabsContentState extends State<BottomTabsContent> {
  int _firstIndex = 0;
  int _secondIndex = 0;

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color contentColor =
        isLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

    List<Widget> tabs(int count, ValueChanged<int> onSelect) {
      return <Widget>[
        for (int index = 0; index < count; index++)
          LiquidBottomTab(
            onPressed: () => onSelect(index),
            children: <Widget>[
              FlightIcon(size: 28, color: contentColor),
              Text(
                'Tab ${index + 1}',
                style: TextStyle(color: contentColor, fontSize: 12),
              ),
            ],
          ),
      ];
    }

    return BackdropDemoScaffold(
      builder: (BuildContext context, LayerBackdrop backdrop) {
        return <Widget>[
          Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 32,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: LiquidBottomTabs(
                selectedTabIndex: _firstIndex,
                onTabSelected: (int index) => setState(() => _firstIndex = index),
                backdrop: backdrop,
                tabsCount: 3,
                children: tabs(3, (int i) => setState(() => _firstIndex = i)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: LiquidBottomTabs(
                selectedTabIndex: _secondIndex,
                onTabSelected: (int index) => setState(() => _secondIndex = index),
                backdrop: backdrop,
                tabsCount: 4,
                children: tabs(4, (int i) => setState(() => _secondIndex = i)),
              ),
            ),
          ],
          ),
        ];
      },
    );
  }
}
