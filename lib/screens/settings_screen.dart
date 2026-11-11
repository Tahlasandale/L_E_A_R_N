import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme/catppuccin.dart';
import '../widgets/kawaii_button.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Réglages ⚙️',
          style: TextStyle(fontWeight: FontWeight.w900, color: Catppuccin.sky),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // --- NOTIFICATIONS BOX ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Catppuccin.mantle,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Catppuccin.surface0, width: 2.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🔔', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 10),
                    Text(
                      'Rappels Prédictifs FSRS',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Catppuccin.text),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'L\'application calcule automatiquement le moment où un volume critique de cartes arrive à échéance selon ton rythme FSRS, et planifie une notification sans consommer de batterie en arrière-plan.',
                  style: TextStyle(color: Catppuccin.subtext, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                KawaiiButton.secondary(
                  height: 48,
                  onPressed: () async {
                    await NotificationService().requestPermissions();
                    await NotificationService().showTestNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Catppuccin.mantle,
                          content: Text('⚡ Notification de test envoyée !', style: TextStyle(color: Catppuccin.green)),
                        ),
                      );
                    }
                  },
                  child: const Text('Envoyer une notification test 🔔'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- ABOUT BOX ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Catppuccin.mantle,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Catppuccin.surface0, width: 2.5),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('⚡', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 10),
                    Text(
                      'À propos',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Catppuccin.text),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  'Kawaii Flashcards v1.0.0\n'
                  '• Moteur de répétition espacée FSRS / SM-2\n'
                  '• Base de données Isar NoSQL ultra-rapide\n'
                  '• Thème Catppuccin Mocha Sombre\n'
                  '• Import / Export CSV avec séparateurs sur mesure\n'
                  '• Retours haptiques discrets sur mobile',
                  style: TextStyle(color: Catppuccin.subtext, fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
