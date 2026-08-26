import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import 'catalog_destination.dart';
import 'components/liquid_button.dart';
import 'destinations/adaptive_luminance_glass_content.dart';
import 'destinations/bottom_tabs_content.dart';
import 'destinations/buttons_content.dart';
import 'destinations/control_center_content.dart';
import 'destinations/dialog_content.dart';
import 'destinations/glass_playground_content.dart';
import 'destinations/home_content.dart';
import 'destinations/lazy_scroll_container_content.dart';
import 'destinations/lock_screen_content.dart';
import 'destinations/magnifier_content.dart';
import 'destinations/menu_content.dart';
import 'destinations/progressive_blur_content.dart';
import 'destinations/scroll_container_content.dart';
import 'destinations/slider_content.dart';
import 'destinations/toggle_content.dart';
import 'destinations/toolbar_content.dart';

/// The catalog's navigation host.
///
/// Shows one destination at a time, with a "Back" button over everything but
/// the home screen.
class MainContent extends StatefulWidget {
  const MainContent({super.key});

  @override
  State<MainContent> createState() => _MainContentState();
}

/// Lets the screenshot harness in `main.dart` drive navigation.
void Function(CatalogDestination)? catalogDebugNavigate;

class _MainContentState extends State<MainContent> {
  CatalogDestination _destination = CatalogDestination.home;

  @override
  void initState() {
    super.initState();
    catalogDebugNavigate = _navigate;
  }

  @override
  void dispose() {
    if (catalogDebugNavigate == _navigate) catalogDebugNavigate = null;
    super.dispose();
  }

  void _navigate(CatalogDestination destination) {
    setState(() => _destination = destination);
  }

  void _back() {
    setState(() => _destination = CatalogDestination.home);
  }

  Widget _buildDestination() {
    switch (_destination) {
      case CatalogDestination.home:
        return HomeContent(onNavigate: _navigate);
      case CatalogDestination.buttons:
        return const ButtonsContent();
      case CatalogDestination.toggle:
        return const ToggleContent();
      case CatalogDestination.slider:
        return const SliderContent();
      case CatalogDestination.bottomTabs:
        return const BottomTabsContent();
      case CatalogDestination.menu:
        return const MenuContent();
      case CatalogDestination.toolbar:
        return const ToolbarContent();
      case CatalogDestination.dialog:
        return const DialogContent();
      case CatalogDestination.lockScreen:
        return const LockScreenContent();
      case CatalogDestination.controlCenter:
        return const ControlCenterContent();
      case CatalogDestination.magnifier:
        return const MagnifierContent();
      case CatalogDestination.glassPlayground:
        return const GlassPlaygroundContent();
      case CatalogDestination.adaptiveLuminanceGlass:
        return const AdaptiveLuminanceGlassContent();
      case CatalogDestination.progressiveBlur:
        return const ProgressiveBlurContent();
      case CatalogDestination.scrollContainer:
        return const ScrollContainerContent();
      case CatalogDestination.lazyScrollContainer:
        return const LazyScrollContainerContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool atHome = _destination == CatalogDestination.home;
    return PopScope(
      canPop: atHome,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _back();
      },
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: KeyedSubtree(
              key: ValueKey<CatalogDestination>(_destination),
              child: _buildDestination(),
            ),
          ),
          if (!atHome)
            Align(
              alignment: Alignment.topLeft,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    height: 48,
                    child: LiquidButton(
                      onPressed: _back,
                      backdrop: emptyBackdrop,
                      tint: const Color(0xFF0088FF),
                      children: const <Widget>[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Back',
                            style: TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
