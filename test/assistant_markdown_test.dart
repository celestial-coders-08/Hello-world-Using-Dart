import 'package:flutter/painting.dart';
import 'package:flutter_application_1/Screen/assistant/assistant_chat_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assistant markdown renders double-asterisk text as bold', () {
    final spans = assistantBoldMarkdownSpans('Hello **PawStay** AI');

    expect(spans[0].text, 'Hello ');
    expect(spans[1].text, 'PawStay');
    expect(spans[1].style?.fontWeight, FontWeight.bold);
    expect(spans[2].text, ' AI');
  });

  test('assistant markdown leaves unformatted text unchanged', () {
    final spans = assistantBoldMarkdownSpans('Plain text');

    expect(spans, hasLength(1));
    expect(spans.single.text, 'Plain text');
    expect(spans.single.style, isNull);
  });
}
