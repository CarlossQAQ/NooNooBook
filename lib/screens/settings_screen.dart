import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Appearance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _ThemeOption(
            icon: Icons.light_mode,
            title: 'Light',
            subtitle: 'Default bright theme',
            isSelected: theme.mode == AppThemeMode.light,
            onTap: () => theme.setMode(AppThemeMode.light),
          ),
          _ThemeOption(
            icon: Icons.dark_mode,
            title: 'Dark',
            subtitle: 'Dark theme for low light',
            isSelected: theme.mode == AppThemeMode.dark,
            onTap: () => theme.setMode(AppThemeMode.dark),
          ),
          _ThemeOption(
            icon: Icons.remove_red_eye,
            title: 'Eye Care',
            subtitle: 'Warm tones to reduce eye strain',
            isSelected: theme.mode == AppThemeMode.eyecare,
            onTap: () => theme.setMode(AppThemeMode.eyecare),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({required this.icon, required this.title, required this.subtitle, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? const BorderSide(color: Colors.blueAccent, width: 2) : BorderSide.none,
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? Colors.blueAccent : null),
        title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
        subtitle: Text(subtitle),
        trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blueAccent) : null,
        onTap: onTap,
      ),
    );
  }
}
