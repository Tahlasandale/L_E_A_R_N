import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/deck_provider.dart';
import '../providers/settings_provider.dart';
import '../services/file_saver/file_saver.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
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

  Widget _buildQcmDurationChip(BuildContext context, SettingsProvider settings, double value, String label) {
    final isSelected = (settings.qcmGoodAnswerDuration - value).abs() < 0.05;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        settings.setQcmGoodAnswerDuration(value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Catppuccin.peach : Catppuccin.surface0,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Catppuccin.peach : Catppuccin.surface1),
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

  Future<void> _handleExportJson(BuildContext context) async {
    final storage = Provider.of<StorageService>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    final extraSettings = {
      'desiredRetention': settings.desiredRetention,
      'qcmGoodAnswerDuration': settings.qcmGoodAnswerDuration,
    };

    final jsonContent = await storage.exportFullBackupJson(extraSettings: extraSettings);
    final dateStr = DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', '');
    final fileName = 'Kawaii_Flashcards_Backup_$dateStr.json';

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Catppuccin.mantle,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Exporter la base complète 📦',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Catppuccin.sky),
            ),
            const SizedBox(height: 10),
            const Text(
              'Choisis comment tu souhaites exporter ta sauvegarde intégrale (tous les paquets, toutes les cartes et métriques FSRS).',
              style: TextStyle(color: Catppuccin.subtext, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: KawaiiButton.secondary(
                    height: 48,
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final savedPath = await FileSaverService.saveFile(fileName, jsonContent);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Catppuccin.mantle,
                            content: Text(
                              savedPath != null ? '💾 Sauvegardé : $savedPath' : '⚠️ Erreur de sauvegarde.',
                              style: TextStyle(color: savedPath != null ? Catppuccin.green : Catppuccin.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('💾 Téléchargements'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: KawaiiButton(
                    height: 48,
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await SharePlus.instance.share(
                        ShareParams(
                          text: jsonContent,
                          subject: fileName,
                        ),
                      );
                    },
                    child: const Text('📤 Partager'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleImportJson(BuildContext context) async {
    try {
      List<PlatformFile> files = [];
      try {
        files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
      } catch (_) {
        files = await FilePicker.pickFiles(type: FileType.any);
      }

      if (files.isEmpty) return;

      final bytes = await files.first.xFile.readAsBytes();
      String content;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        content = latin1.decode(bytes);
      }

      if (!context.mounted) return;
      final deckProvider = Provider.of<DeckProvider>(context, listen: false);
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

      // Décodage et restauration
      final stats = await deckProvider.importFullBackup(content);

      // Si le JSON contient des réglages, les appliquer
      try {
        final parsed = jsonDecode(content) as Map<String, dynamic>;
        if (parsed.containsKey('settings')) {
          final s = parsed['settings'] as Map<String, dynamic>;
          if (s.containsKey('desiredRetention')) {
            await settingsProvider.setDesiredRetention((s['desiredRetention'] as num).toDouble());
          }
          if (s.containsKey('qcmGoodAnswerDuration')) {
            await settingsProvider.setQcmGoodAnswerDuration((s['qcmGoodAnswerDuration'] as num).toDouble());
          }
        }
      } catch (_) {}

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Catppuccin.mantle,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Restauration Réussie ! ⚡', style: TextStyle(color: Catppuccin.green, fontWeight: FontWeight.bold)),
            content: Text(
              'La fusion intelligente a été effectuée avec succès :\n\n'
              '• Paquets créés : ${stats['decksAdded'] ?? 0}\n'
              '• Cartes ajoutées : ${stats['cardsAdded'] ?? 0}\n'
              '• Cartes mises à jour : ${stats['cardsUpdated'] ?? 0}',
              style: const TextStyle(color: Catppuccin.text, height: 1.4),
            ),
            actions: [
              KawaiiButton(
                height: 40,
                width: 100,
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Génial !'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Catppuccin.mantle,
            content: Text('⚠️ Erreur lors de l\'importation : $e', style: const TextStyle(color: Catppuccin.red)),
          ),
        );
      }
    }
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

          // --- MODE COLLES (DURÉE BONNE RÉPONSE) ---
          Consumer<SettingsProvider>(
            builder: (context, settingsProvider, _) {
              final duration = settingsProvider.qcmGoodAnswerDuration;

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
                        const Text('⏱️', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Mode Colles : Affichage Bonne Réponse',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Catppuccin.text),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Catppuccin.peach.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Catppuccin.peach, width: 2),
                          ),
                          child: Text(
                            '${duration}s',
                            style: const TextStyle(
                              color: Catppuccin.peach,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Durée d\'affichage en grand format de la bonne réponse en bas de l\'écran avant d\'enchaîner sur la carte suivante.',
                      style: TextStyle(color: Catppuccin.subtext, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Catppuccin.peach,
                        inactiveTrackColor: Catppuccin.surface0,
                        thumbColor: Catppuccin.peach,
                        overlayColor: Catppuccin.peach.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: duration,
                        min: 0.5,
                        max: 3.0,
                        divisions: 25,
                        label: '${duration}s',
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          settingsProvider.setQcmGoodAnswerDuration(val);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQcmDurationChip(context, settingsProvider, 0.5, '0.5s ⚡'),
                        _buildQcmDurationChip(context, settingsProvider, 1.0, '1.0s (défaut) 🎯'),
                        _buildQcmDurationChip(context, settingsProvider, 1.5, '1.5s 📖'),
                        _buildQcmDurationChip(context, settingsProvider, 2.0, '2.0s 🧘'),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // --- SAUVEGARDE & RESTAURATION (JSON 📦) ---
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
                    Text('📦', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 10),
                    Text(
                      'Sauvegarde & Restauration (JSON)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Catppuccin.text),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Exporte ou importe l\'intégralité de tes paquets, cartes, réglages et historique FSRS dans un fichier JSON universel.',
                  style: TextStyle(color: Catppuccin.subtext, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: KawaiiButton(
                        height: 48,
                        onPressed: () => _handleExportJson(context),
                        child: const Text('Exporter JSON 📤'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: KawaiiButton.secondary(
                        height: 48,
                        onPressed: () => _handleImportJson(context),
                        child: const Text('Importer JSON 📥'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
                  'Kawaii Flashcards v1.1.3\n'
                  '• Moteur de répétition espacée FSRS / SM-2 avec rétention paramétrable (70%-98%)\n'
                  '• Double persistance Isar NoSQL + Miroir JSON local automatique\n'
                  '• Sauvegarde & Restauration intégrale JSON avec métriques FSRS\n'
                  '• Thème Catppuccin Macchiato Sombre\n'
                  '• Import / Export CSV avec séparateurs sur mesure & téléchargements\n'
                  '• Mode Colles Arcade vertical avec affichage grand format de la bonne réponse\n'
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
