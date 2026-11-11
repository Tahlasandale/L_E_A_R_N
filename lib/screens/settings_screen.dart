import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import '../theme/catppuccin.dart';
import '../widgets/kawaii_button.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _buildPresetChip(BuildContext context, SettingsProvider settings, double value, String label) {
    final isSelected = (settings.desiredRetention - value).abs() < 0.01;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        settings.setDesiredRetention(value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Catppuccin.mauve : Catppuccin.surface0,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Catppuccin.mauve : Catppuccin.surface1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Catppuccin.crust : Catppuccin.text,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

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
          // --- TAUX DE RÉTENTION FSRS ---
          Consumer<SettingsProvider>(
            builder: (context, settingsProvider, _) {
              final percent = settingsProvider.desiredRetentionPercent;

              String advice;
              if (percent >= 95) {
                advice = '⚡ Rétention maximale : intervalles très courts pour minimiser les oublis. Charge quotidienne plus soutenue.';
              } else if (percent >= 90) {
                advice = '🎯 Équilibre optimal (recommandé FSRS) : excellent compromis entre mémorisation solide et volume de révisions.';
              } else if (percent >= 85) {
                advice = '📖 Rythme standard : intervalles confortables avec tolérance modérée à l\'oubli.';
              } else {
                advice = '🏖️ Rythme détendu : intervalles espacés pour alléger la charge de travail si tu as peu de temps disponible.';
              }

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Catppuccin.mantle,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Catppuccin.surface0, width: 2.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🧠', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Taux de Rétention FSRS',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Catppuccin.text),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Catppuccin.mauve.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Catppuccin.mauve, width: 2),
                          ),
                          child: Text(
                            '$percent%',
                            style: const TextStyle(
                              color: Catppuccin.mauve,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Règle la probabilité cible de te souvenir d\'une carte à son échéance. Le moteur FSRS adapte dynamiquement l\'espacement des révisions.',
                      style: TextStyle(color: Catppuccin.subtext, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Catppuccin.mauve,
                        inactiveTrackColor: Catppuccin.surface0,
                        thumbColor: Catppuccin.mauve,
                        overlayColor: Catppuccin.mauve.withValues(alpha: 0.2),
                        valueIndicatorColor: Catppuccin.mantle,
                        valueIndicatorTextStyle: const TextStyle(color: Catppuccin.mauve, fontWeight: FontWeight.bold),
                      ),
                      child: Slider(
                        value: settingsProvider.desiredRetention,
                        min: 0.70,
                        max: 0.98,
                        divisions: 28,
                        label: '$percent%',
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          settingsProvider.setDesiredRetention(val);
                        },
                      ),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('70% (Doux)', style: TextStyle(color: Catppuccin.overlay, fontSize: 11)),
                        Text('90% (Optimal)', style: TextStyle(color: Catppuccin.mauve, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('98% (Intense)', style: TextStyle(color: Catppuccin.overlay, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Préréglages rapides
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPresetChip(context, settingsProvider, 0.80, '80% 🏖️'),
                        _buildPresetChip(context, settingsProvider, 0.85, '85% 📖'),
                        _buildPresetChip(context, settingsProvider, 0.90, '90% 🎯'),
                        _buildPresetChip(context, settingsProvider, 0.95, '95% ⚡'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Catppuccin.crust,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Catppuccin.surface0),
                      ),
                      child: Text(
                        advice,
                        style: const TextStyle(color: Catppuccin.subtext, fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

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
                  'Kawaii Flashcards v1.1.0\n'
                  '• Moteur de répétition espacée FSRS / SM-2 avec rétention paramétrable (70%-98%)\n'
                  '• Base de données Isar NoSQL ultra-rapide\n'
                  '• Thème Catppuccin Macchiato Sombre\n'
                  '• Import / Export CSV avec séparateurs sur mesure & téléchargements\n'
                  '• Mode Colles 2x2 Arcade avec zoom au maintien long\n'
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
