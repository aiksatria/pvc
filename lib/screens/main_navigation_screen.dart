import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../utils/app_localizations.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'telegram_proxy_screen.dart';
import 'tools_screen.dart';
import 'store_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const HomeScreen(),
    const TelegramProxyScreen(),
    const StoreScreen(),
    const ToolsScreen(),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: Scaffold(
            body: IndexedStack(index: _currentIndex, children: _screens),
            bottomNavigationBar: ClipRRect(
              borderRadius: BorderRadius.circular(20.0),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                backgroundColor: AppTheme.surfaceContainer,
                elevation: 8,
                selectedItemColor: AppTheme.primaryBlue,
                unselectedItemColor: Colors.grey,
                type: BottomNavigationBarType.fixed,
                selectedFontSize: 12,
                unselectedFontSize: 10,
                iconSize: 24,
                showSelectedLabels: true,
                showUnselectedLabels: true,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
                items: [
                  BottomNavigationBarItem(
                    icon: Container(
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentIndex == 0
                            ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                            : Colors.transparent,
                      ),
                      child: const Icon(Icons.vpn_key_rounded),
                    ),
                    label: context.tr(TranslationKeys.navVpn),
                  ),
                  BottomNavigationBarItem(
                    icon: Container(
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentIndex == 1
                            ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                            : Colors.transparent,
                      ),
                      child: const Icon(Icons.telegram_rounded),
                    ),
                    label: context.tr(TranslationKeys.navProxy),
                  ),
                  BottomNavigationBarItem(
                    icon: Container(
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentIndex == 2
                            ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                            : Colors.transparent,
                      ),
                      child: const Icon(Icons.storefront_rounded),
                    ),
                    label: context.tr(TranslationKeys.navStore),
                  ),
                  BottomNavigationBarItem(
                    icon: Container(
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentIndex == 3
                            ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                            : Colors.transparent,
                      ),
                      child: const Icon(Icons.handyman_rounded),
                    ),
                    label: context.tr(TranslationKeys.navTools),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
