import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/verse.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/circle_service.dart';

/// Runs a change to a circle; the server answers with the circle as it now is. False when it failed
/// (and the person was told why).
typedef CircleChange = Future<bool> Function(Future<CircleDetail> Function() action);

/// A Bible verse ("JHN 3:16") in the reader's language, for a verse shared in a circle.
final circleVerseProvider = FutureProvider.family<Verse?, String>((ref, verse) {
  final lang = ref.watch(settingsProvider.select((s) => s.lang));
  return ref.watch(bibleProvider).fullVerse(verse, lang);
});

String circleProblemText(AppLocalizations l, Object e) => switch (e) {
  CircleException(problem: CircleProblem.notFound) => l.circleNotFound,
  CircleException(problem: CircleProblem.full) => l.circleFull,
  CircleException(problem: CircleProblem.tooMany) => l.circleTooMany,
  CircleException(problem: CircleProblem.notAllowed) => l.circleNotAllowed,
  _ => l.circleOffline,
};

void sayInCircles(BuildContext context, String text, {SnackBarAction? action}) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating, action: action));

/// Asks for an optional note to go with a shared prayer or verse; null when cancelled.
Future<String?> askCircleNote(BuildContext context, IconData icon, String title) {
  final l = AppLocalizations.of(context);
  final note = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(icon, color: AppColors.gold),
      title: Text(title, textAlign: TextAlign.center),
      content: TextField(
        controller: note,
        autofocus: true,
        minLines: 1,
        maxLines: 4,
        maxLength: 300,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: l.circleNoteHint, counterText: ''),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, note.text.trim()), child: Text(l.share)),
      ],
    ),
  ).whenComplete(note.dispose);
}

/// Asks for some text — a praise report, a testimony, a group's name; null when cancelled.
/// [optional]: may be left empty (answers ''). [lines] 1: a single line.
Future<String?> askCircleText(
  BuildContext context, {
  required String title,
  required String hint,
  required String action,
  bool optional = false,
  int maxLength = 1000,
  int lines = 6,
  IconData? icon,
}) {
  final text = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final ready = optional || text.text.trim().isNotEmpty;
        return AlertDialog(
          backgroundColor: AppColors.ivory,
          icon: icon == null ? null : Icon(icon, color: AppColors.gold),
          title: Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.serif(24, weight: FontWeight.w700),
          ),
          content: TextField(
            controller: text,
            autofocus: true,
            minLines: lines == 1 ? 1 : 3,
            maxLines: lines,
            maxLength: maxLength,
            textCapitalization: lines == 1 ? TextCapitalization.words : TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: hint, counterText: ''),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: ready ? () => Navigator.pop(ctx, text.text.trim()) : null,
              child: Text(action),
            ),
          ],
        );
      },
    ),
  ).whenComplete(text.dispose);
}

/// One of the person's circles to share into (not those they still wait to join); null when they
/// have none (after saying so) or cancel. With one circle, that one.
Future<CircleSummary?> pickCircle(BuildContext context, CircleService service) async {
  final l = AppLocalizations.of(context);
  var circles = service.saved;
  try {
    circles = await service.mine();
  } catch (_) {}
  circles = [
    for (final c in circles)
      if (!c.pending) c,
  ];
  if (!context.mounted) return null;
  if (circles.isEmpty) {
    sayInCircles(
      context,
      l.circleNone,
      action: SnackBarAction(label: l.circlesTitle, onPressed: () => context.push('/circles')),
    );
    return null;
  }
  if (circles.length == 1) return circles.single;
  return showModalBottomSheet<CircleSummary>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.ivoryCard,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(l.circleChoose, style: AppText.serif(22, weight: FontWeight.w700)),
            ),
            for (final c in circles)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.sand,
                  child: Icon(Icons.groups_rounded, color: AppColors.ember),
                ),
                title: Text(
                  c.parent == null ? c.name : '${c.parent} › ${c.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(l.circleMembers(c.members)),
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    ),
  );
}

/// From the Bible: shares [verse] into one of the person's circles, with a note — the week's sermon,
/// say. Each member reads it in their own language.
Future<void> shareVerseToCircle(BuildContext context, Verse verse) async {
  final l = AppLocalizations.of(context);
  final service = ProviderScope.containerOf(context, listen: false).read(circleServiceProvider);
  final circle = await pickCircle(context, service);
  if (circle == null || !context.mounted) return;
  final note = await askCircleNote(context, Icons.menu_book_rounded, verse.reference);
  if (note == null || !context.mounted) return;
  try {
    await service.shareVerse(circle.code, verse.ref, note);
    if (context.mounted) sayInCircles(context, l.circleSharedTo(circle.name));
  } catch (e) {
    if (context.mounted) sayInCircles(context, circleProblemText(l, e));
  }
}
