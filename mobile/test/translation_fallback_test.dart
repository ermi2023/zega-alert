import 'package:flutter_test/flutter_test.dart';
import 'package:zega_alert_mobile/services/api.dart';

void main() {
  const original = 'Missing person was last seen near the central market.';

  test('rejects an API response that returns the original text', () {
    expect(
      Api.hasUsableTranslation(
        {'text': original, 'source': 'original'},
        original,
      ),
      isFalse,
    );
  });

  test('accepts a translated response', () {
    expect(
      Api.hasUsableTranslation(
        {'text': 'የጠፋ ሰው በማዕከላዊ ገበያ አቅራቢያ ነበር።', 'source': 'google-public'},
        original,
      ),
      isTrue,
    );
  });
}
