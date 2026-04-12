import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../widgets/mini_player.dart';

// ── Nav data ─────────────────────────────────────────────────────────────────
class _NavItem {
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.path, this.icon, this.activeIcon, this.label);
}

const _navItems = [
  _NavItem('/home', Icons.home_outlined, Icons.home_rounded, 'Home'),
  _NavItem('/search', Icons.search_outlined, Icons.search_rounded, 'Search'),
  _NavItem('/library', Icons.library_music_outlined,
      Icons.library_music_rounded, 'Library'),
  _NavItem('/settings', Icons.settings_outlined, Icons.settings_rounded,
      'Settings'),
];

// ── Shell scaffold — platform-aware, inspired by Catalyst ────────────────────
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({super.key, required this.shell});
  final StatefulNavigationShell shell;

  void _go(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIOS = !kIsWeb && Platform.isIOS;

    if (isIOS) return _IPhoneShell(shell: shell, onTap: _go);

    return _AndroidShell(shell: shell, onTap: _go);
  }
}

// ── Android — Material You NavigationBar ─────────────────────────────────────
class _AndroidShell extends StatelessWidget {
  const _AndroidShell({required this.shell, required this.onTap});
  final StatefulNavigationShell shell;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          shell,
          const Positioned(
            left: 0,
            right: 0,
            bottom: 80,
            child: MiniPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: onTap,
        backgroundColor: cs.surfaceContainer,
        elevation: 0,
        height: 72,
        destinations: _navItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.activeIcon),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}

// ── iOS — Glass frosted tab bar (exactly like Catalyst) ──────────────────────
class _IPhoneShell extends StatelessWidget {
  const _IPhoneShell({required this.shell, required this.onTap});
  final StatefulNavigationShell shell;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        children: [
          shell,
          const Positioned(
            left: 0,
            right: 0,
            bottom: 80,
            child: MiniPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: _GlassTabBar(
        selectedIndex: shell.currentIndex,
        onTap: onTap,
      ),
    );
  }
}

class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({required this.selectedIndex, required this.onTap});
  final int selectedIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.72),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 54,
              child: Row(
                children: List.generate(_navItems.length, (i) {
                  final item = _navItems[i];
                  final selected = i == selectedIndex;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: selected ? 1.12 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              selected ? item.activeIcon : item.icon,
                              size: 22,
                              color: selected
                                  ? cs.primary
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : Colors.black.withValues(alpha: 0.4)),
                            ),
                          ),
                          const SizedBox(height: 3),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: selected
                                  ? cs.primary
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : Colors.black.withValues(alpha: 0.4)),
                            ),
                            child: Text(item.label),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
