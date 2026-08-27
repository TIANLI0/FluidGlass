import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';

class MenuContent extends StatefulWidget {
  const MenuContent({super.key});

  @override
  State<MenuContent> createState() => _MenuContentState();
}

class _MenuContentState extends State<MenuContent> {
  static const List<String> _sortOptions = <String>[
    'Name',
    'Date modified',
    'Size',
  ];

  int _sortIndex = 1;
  String _lastAction = 'Nothing yet';

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color contentColor =
        isLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

    return BackdropDemoScaffold(
      builder: (BuildContext context, LayerBackdrop backdrop) {
        Widget Function(BuildContext, bool, VoidCallback) trigger(
          String label,
        ) {
          return (BuildContext context, bool isOpen, VoidCallback toggle) {
            return LiquidButton(
              onPressed: toggle,
              backdrop: backdrop,
              tint: isOpen ? const Color(0xFF0088FF) : null,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    color: isOpen ? const Color(0xFFFFFFFF) : contentColor,
                    fontSize: 16,
                  ),
                ),
                Icon(
                  Icons.expand_more,
                  size: 20,
                  color: isOpen ? const Color(0xFFFFFFFF) : contentColor,
                ),
              ],
            );
          };
        }

        return <Widget>[
          Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 40,
            children: <Widget>[
              // Opens downwards, lined up with the anchor's leading edge.
              LiquidMenu(
                backdrop: backdrop,
                anchorBuilder: trigger('Sort by'),
                items: <LiquidMenuItem>[
                  for (int i = 0; i < _sortOptions.length; i++)
                    LiquidMenuItem(
                      label: _sortOptions[i],
                      isSelected: i == _sortIndex,
                      onSelected: () => setState(() => _sortIndex = i),
                    ),
                ],
              ),
              Text(
                'Sorted by ${_sortOptions[_sortIndex]}',
                style: TextStyle(color: contentColor, fontSize: 15),
              ),
              // Opens upwards, lined up with the anchor's trailing edge, and
              // carries icons plus a destructive row.
              LiquidMenu(
                backdrop: backdrop,
                side: LiquidMenuSide.above,
                alignment: Alignment.topRight,
                panelWidth: 232,
                anchorBuilder: trigger('Actions'),
                items: <LiquidMenuItem>[
                  LiquidMenuItem(
                    label: 'Share',
                    icon: Icons.ios_share,
                    onSelected: () => setState(() => _lastAction = 'Share'),
                  ),
                  LiquidMenuItem(
                    label: 'Duplicate',
                    icon: Icons.copy_all_outlined,
                    onSelected: () => setState(() => _lastAction = 'Duplicate'),
                  ),
                  LiquidMenuItem(
                    label: 'Rename',
                    icon: Icons.drive_file_rename_outline,
                    onSelected: () => setState(() => _lastAction = 'Rename'),
                  ),
                  LiquidMenuItem(
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    isDestructive: true,
                    onSelected: () => setState(() => _lastAction = 'Delete'),
                  ),
                ],
              ),
              Text(
                'Last action: $_lastAction',
                style: TextStyle(
                  color: contentColor.withValues(alpha: 0.68),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ];
      },
    );
  }
}
