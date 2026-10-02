import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/device_settings.dart';
import '../../core/languages.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import 'voice_picker_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.profileTitle, style: AppText.serif(24, weight: FontWeight.w600))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120), // clear of the bottom bar
        children: [
          const Center(child: LogoMark(size: 84)),
          const SizedBox(height: 12),
          Center(
            child: Text(settings.name.isEmpty ? l.friend : settings.name,
                style: AppText.serif(28, weight: FontWeight.w600)),
          ),
          const SizedBox(height: 20),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(l.yourName),
                  subtitle: settings.name.isEmpty ? null : Text(settings.name),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _editName(context, ref, settings.name),
                ),
                const Divider(height: 1, color: AppColors.sand),
                ListTile(
                  leading: const Icon(Icons.phone_iphone_rounded),
                  title: Text(l.mobileNumber),
                  subtitle: settings.phone.isEmpty ? null : Text(settings.phone),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/signin'),
                ),
                const Divider(height: 1, color: AppColors.sand),
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(l.language),
                  trailing: Text(settings.language.nativeName, style: const TextStyle(color: AppColors.inkSoft)),
                  onTap: () => _pickLanguage(context, ref, settings.lang),
                ),
                const Divider(height: 1, color: AppColors.sand),
                ListTile(
                  leading: const Icon(Icons.record_voice_over_outlined),
                  title: Text(l.voice),
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(settings.voice.isEmpty ? l.voiceMale : settings.voice,
                        overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.inkSoft)),
                  ),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    backgroundColor: AppColors.ivoryCard,
                    builder: (_) => const VoicePickerSheet(),
                  ),
                ),
                const _VoiceMissingNotice(),
                const Divider(height: 1, color: AppColors.sand),
                ListTile(
                  leading: const Icon(Icons.format_size_rounded),
                  title: Text(l.textSize),
                  trailing: SegmentedButton<double>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: [
                      for (final (scale, size) in [(1.0, 13.0), (1.15, 16.0), (1.3, 19.0)])
                        ButtonSegment(value: scale, label: Text('A', style: TextStyle(fontSize: size))),
                    ],
                    selected: {settings.textScale},
                    onSelectionChanged: (v) => ref.read(settingsProvider.notifier).setTextScale(v.first),
                  ),
                ),
                const Divider(height: 1, color: AppColors.sand),
                ListTile(
                  leading: const Icon(Icons.notifications_none_rounded),
                  title: Text(l.dailyReminder),
                  subtitle: settings.reminder == null ? null : Text(_timeOf(settings.reminder!).format(context)),
                  trailing: Switch(
                    value: settings.reminder != null,
                    activeTrackColor: AppColors.gold,
                    onChanged: (on) => on
                        ? _pickReminder(context, ref, 7 * 60)
                        : ref.read(settingsProvider.notifier).setReminder(null),
                  ),
                  onTap: () => _pickReminder(context, ref, settings.reminder ?? 7 * 60),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SoftCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.rate_review_outlined),
              title: Text(l.sendFeedback),
              subtitle: Text(l.feedbackHint),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/feedback'),
            ),
          ),
          const SizedBox(height: 16),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.about, style: AppText.serif(20, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(l.aboutBody, style: const TextStyle(height: 1.45)),
                const SizedBox(height: 14),
                Text(l.scriptureSource, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                FutureBuilder(
                  future: ref.read(bibleProvider).attribution(settings.lang),
                  builder: (_, snap) => Text(snap.data ?? '',
                      style: const TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static TimeOfDay _timeOf(int minuteOfDay) => TimeOfDay(hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60);

  /// Picks the reminder time, asking for notification permission the first time.
  Future<void> _pickReminder(BuildContext context, WidgetRef ref, int initial) async {
    final time = await showTimePicker(context: context, initialTime: _timeOf(initial));
    if (time == null) return;
    if (!await ref.read(reminderServiceProvider).requestPermission()) return;
    await ref.read(settingsProvider.notifier).setReminder(time.hour * 60 + time.minute);
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, String current) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.yourName),
        content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) await ref.read(settingsProvider.notifier).setName(name);
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref, String current) async {
    final code = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.ivoryCard,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final lang in appLanguages)
              ListTile(
                title: Text(lang.nativeName),
                subtitle: lang.nativeName == lang.englishName ? null : Text(lang.englishName),
                trailing: lang.code == current ? const Icon(Icons.check_rounded, color: AppColors.gold) : null,
                onTap: () => Navigator.pop(ctx, lang.code),
              ),
          ],
        ),
      ),
    );
    if (code != null) await ref.read(settingsProvider.notifier).setLanguage(code);
  }
}

/// Whether the phone can read the current language aloud. Re-checked when the user
/// comes back from the phone's settings, after downloading a voice.
final _voiceAvailableProvider = FutureProvider.autoDispose<bool>((ref) {
  final lang = ref.watch(settingsProvider.select((s) => s.language));
  return ref.read(ttsProvider).hasVoice(lang);
});

/// "This phone has no voice for తెలుగు" with a Download voice button; nothing when a voice is installed.
class _VoiceMissingNotice extends ConsumerStatefulWidget {
  const _VoiceMissingNotice();

  @override
  ConsumerState<_VoiceMissingNotice> createState() => _VoiceMissingNoticeState();
}

class _VoiceMissingNoticeState extends ConsumerState<_VoiceMissingNotice> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(_voiceAvailableProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(_voiceAvailableProvider).value ?? true) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final language = ref.watch(settingsProvider.select((s) => s.language));
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.noVoice(language.nativeName), style: const TextStyle(height: 1.4)),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: DeviceSettings.ttsVoices,
              icon: const Icon(Icons.download_rounded),
              label: Text(l.downloadVoice),
            ),
          ),
        ],
      ),
    );
  }
}
