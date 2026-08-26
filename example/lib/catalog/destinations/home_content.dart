import 'package:flutter/material.dart';

import '../catalog_destination.dart';

/// The catalog's index screen.
class HomeContent extends StatelessWidget {
  const HomeContent({super.key, required this.onNavigate});

  final ValueChanged<CatalogDestination> onNavigate;

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color contentColor =
        isLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

    return SingleChildScrollView(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              child: Text(
                'Backdrop Catalog',
                style: TextStyle(
                  color: contentColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _Subtitle('Liquid glass components'),
                _ListItem(
                  label: 'Buttons',
                  onTap: () => onNavigate(CatalogDestination.buttons),
                ),
                _ListItem(
                  label: 'Toggle',
                  onTap: () => onNavigate(CatalogDestination.toggle),
                ),
                _ListItem(
                  label: 'Slider',
                  onTap: () => onNavigate(CatalogDestination.slider),
                ),
                _ListItem(
                  label: 'Bottom tabs',
                  onTap: () => onNavigate(CatalogDestination.bottomTabs),
                ),
                _ListItem(
                  label: 'Menu',
                  onTap: () => onNavigate(CatalogDestination.menu),
                ),
                _ListItem(
                  label: 'Toolbar & controls',
                  onTap: () => onNavigate(CatalogDestination.toolbar),
                ),
                _ListItem(
                  label: 'Dialog',
                  onTap: () => onNavigate(CatalogDestination.dialog),
                ),
                const _Subtitle('System UIs'),
                _ListItem(
                  label: 'Lock screen (SDF texture)',
                  onTap: () => onNavigate(CatalogDestination.lockScreen),
                ),
                _ListItem(
                  label: 'Control center',
                  onTap: () => onNavigate(CatalogDestination.controlCenter),
                ),
                _ListItem(
                  label: 'Magnifier',
                  onTap: () => onNavigate(CatalogDestination.magnifier),
                ),
                const _Subtitle('Experiments'),
                _ListItem(
                  label: 'Glass playground',
                  onTap: () => onNavigate(CatalogDestination.glassPlayground),
                ),
                _ListItem(
                  label: 'Adaptive luminance glass',
                  onTap: () =>
                      onNavigate(CatalogDestination.adaptiveLuminanceGlass),
                ),
                _ListItem(
                  label: 'Progressive blur',
                  onTap: () => onNavigate(CatalogDestination.progressiveBlur),
                ),
                _ListItem(
                  label: 'Scroll container',
                  onTap: () => onNavigate(CatalogDestination.scrollContainer),
                ),
                _ListItem(
                  label: 'Lazy scroll container',
                  onTap: () =>
                      onNavigate(CatalogDestination.lazyScrollContainer),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: SizedBox(
        width: double.infinity,
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0088FF),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ListItem extends StatelessWidget {
  const _ListItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color contentColor =
        isLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            label,
            style: TextStyle(color: contentColor, fontSize: 17),
          ),
        ),
      ),
    );
  }
}
