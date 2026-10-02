import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jesus_answers/core/languages.dart';
import 'package:jesus_answers/services/feedback/feedback_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo.setMockInitialValues(
    appName: 'JesusAnswers',
    packageName: 'com.jesusanswers.jesus_answers',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );

  test('feedback goes to the form with the message and phone details, never empty', () async {
    final posts = <http.Request>[];
    final service = FeedbackService(client: MockClient((r) async {
      posts.add(r);
      return http.Response('', 200);
    }));

    expect(await service.send('   ', languageFor('te')), isFalse);
    expect(posts, isEmpty);

    expect(FeedbackForm.configured, isTrue);
    expect(await service.send('  The Telugu voice is too fast ', languageFor('te')), isTrue);
    final sent = posts.single;
    expect(sent.url.path, '/forms/d/e/${FeedbackForm.formId}/formResponse');
    expect(sent.bodyFields['entry.${FeedbackForm.messageEntry}'], 'The Telugu voice is too fast');
    expect(sent.bodyFields['entry.${FeedbackForm.detailsEntry}'], startsWith('JesusAnswers 1.0.0 (1) · Telugu · '));
  });

  test('a failed send reports false so the user can try again', () async {
    final service = FeedbackService(client: MockClient((_) async => http.Response('', 401)));
    expect(await service.send('Hello', languageFor('en')), isFalse);
  });
}
