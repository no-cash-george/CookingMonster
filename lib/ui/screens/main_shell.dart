import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../widgets/platform_primitives.dart';
import 'ai_import_screen.dart';
import 'recipe_editor_screen.dart';
import 'recipes_screen.dart';
import 'receive_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  final AppState appState;
  const MainShell({super.key, required this.appState});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  void _openAddRecipe() {
    final isApple = widget.appState.isAppleStyle(context);
    Navigator.of(context).push(
      isApple
          ? CupertinoPageRoute(builder: (_) => RecipeEditorScreen(appState: widget.appState))
          : MaterialPageRoute(builder: (_) => RecipeEditorScreen(appState: widget.appState)),
    );
  }

  void _openImportFromAi() {
    final isApple = widget.appState.isAppleStyle(context);
    Navigator.of(context).push(
      isApple
          ? CupertinoPageRoute(builder: (_) => AiImportScreen(appState: widget.appState))
          : MaterialPageRoute(builder: (_) => AiImportScreen(appState: widget.appState)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isApple = widget.appState.isAppleStyle(context);
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;

    final pages = [
      RecipesScreen(appState: widget.appState),
      ReceiveScreen(appState: widget.appState),
      SettingsScreen(appState: widget.appState),
    ];

    if (isApple) {
      return Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            IndexedStack(index: _selectedIndex, children: pages),
            // Floating Liquid Glass Action Buttons positioned cleanly above the bottom bar & Home Indicator
            if (_selectedIndex == 0)
              Positioned(
                left: 20,
                right: 20,
                bottom: bottomSafeInset + 92,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _openImportFromAi,
                          child: LiquidGlassContainer(
                            borderRadius: BorderRadius.circular(30),
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.sparkles, size: 18, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Import AI',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _openAddRecipe,
                          child: LiquidGlassContainer(
                            borderRadius: BorderRadius.circular(30),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.add, size: 20, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Add Recipe',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: LiquidGlassContainer(
              borderRadius: BorderRadius.circular(32),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _AppleNavItem(
                    icon: CupertinoIcons.book,
                    activeIcon: CupertinoIcons.book_fill,
                    label: 'Recipes',
                    selected: _selectedIndex == 0,
                    onTap: () => setState(() => _selectedIndex = 0),
                  ),
                  _AppleNavItem(
                    icon: CupertinoIcons.qrcode_viewfinder,
                    activeIcon: CupertinoIcons.qrcode_viewfinder,
                    label: 'Receive',
                    selected: _selectedIndex == 1,
                    onTap: () => setState(() => _selectedIndex = 1),
                  ),
                  _AppleNavItem(
                    icon: CupertinoIcons.gear,
                    activeIcon: CupertinoIcons.gear_solid,
                    label: 'Settings',
                    selected: _selectedIndex == 2,
                    onTap: () => setState(() => _selectedIndex = 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Android Material You Shell
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      floatingActionButton: _selectedIndex == 0
          ? Padding(
              padding: const EdgeInsets.only(left: 32),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: 'import_ai_fab',
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                      onPressed: _openImportFromAi,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Import AI'),
                    ),
                    const SizedBox(width: 10),
                    FloatingActionButton.extended(
                      heroTag: 'add_recipe_fab',
                      onPressed: _openAddRecipe,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Recipe'),
                    ),
                  ],
                ),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Recipes',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Receive',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _AppleNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AppleNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: selected ? activeColor.withValues(alpha: 0.14) : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon, size: 22, color: selected ? activeColor : inactiveColor),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
