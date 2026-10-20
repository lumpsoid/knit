import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';

/// The §7.4 example identity (mira). The worked examples write the full 64-hex
/// key once (§7.4.1) then abbreviate; the signed bytes always carry the full key.
const String pub =
    '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08';

void main() {
  group('CanonicalSerializer.string — §7.4 golden bytes', () {
    test('7.4.1 collection put matches byte-for-byte', () {
      final s = Snapshot(
        type: EntityType.collection,
        id: '0192f1a2-3b4c-7def-8123-000000000001',
        author: pub,
        createdBy: pub,
        createdAt: 1718020800000,
        hlc: const Hlc(1718020800000, 0),
        deleted: false,
        sig: 'ignored-not-in-payload',
        content: const {
          'title': 'Espresso dialing-in',
          'description': null,
          'cover_attachment_id': null,
          'archived_at': null,
        },
      );

      const expected =
          '{"archived_at":null,"author":"$pub","cover_attachment_id":null,'
          '"created_at":1718020800000,"created_by":"$pub","deleted":0,'
          '"description":null,'
          '"hlc_counter":0,"hlc_ms":1718020800000,'
          '"id":"0192f1a2-3b4c-7def-8123-000000000001","t":"collection",'
          '"title":"Espresso dialing-in"}';

      expect(CanonicalSerializer.string(s), expected);
    });

    test(
      '7.4.3 card put matches (full key substituted for the abbreviation)',
      () {
        final s = Snapshot(
          type: EntityType.card,
          id: '0192f1a2-3b4c-7def-8123-00000000000a',
          author: pub,
          createdBy: pub,
          createdAt: 1718020860000,
          hlc: const Hlc(1718020860000, 0),
          deleted: false,
          sig: '',
          placement: const Hlc(1718020860000, 0),
          position: 'a0',
          content: const {
            'collection_id': '0192f1a2-3b4c-7def-8123-000000000001',
            'kind': 'text',
            'text': 'Grind finer if the shot runs too fast.',
            'attachment_id': null,
            'settled_at': null,
          },
        );

        const expected =
            '{"attachment_id":null,"author":"$pub",'
            '"collection_id":"0192f1a2-3b4c-7def-8123-000000000001",'
            '"created_at":1718020860000,"created_by":"$pub","deleted":0,'
            '"hlc_counter":0,"hlc_ms":1718020860000,'
            '"id":"0192f1a2-3b4c-7def-8123-00000000000a","kind":"text",'
            '"position":"a0","position_counter":0,"position_ms":1718020860000,'
            '"settled_at":null,"t":"card","text":"Grind finer if the shot runs too fast."}';

        expect(CanonicalSerializer.string(s), expected);
      },
    );

    test('7.4.4 card delete keeps placement, bumps hlc, deleted:1', () {
      final s = Snapshot(
        type: EntityType.card,
        id: '0192f1a2-3b4c-7def-8123-00000000000a',
        author: pub,
        createdBy: pub,
        createdAt: 1718020860000,
        hlc: const Hlc(1718020980000, 0),
        deleted: true,
        sig: '',
        placement: const Hlc(1718020860000, 0),
        position: 'a0',
        content: const {
          'collection_id': '0192f1a2-3b4c-7def-8123-000000000001',
          'kind': 'text',
          'text': 'Grind finer if the shot runs too fast.',
          'attachment_id': null,
          'settled_at': null,
        },
      );

      final out = CanonicalSerializer.string(s);
      expect(out, contains('"deleted":1'));
      expect(out, contains('"hlc_ms":1718020980000'));
      expect(out, contains('"position_ms":1718020860000'), reason: 'frozen');
    });

    test('7.4.7 profile put — id == author == created_by', () {
      final s = Snapshot(
        type: EntityType.profile,
        id: pub,
        author: pub,
        createdBy: pub,
        createdAt: 1718020700000,
        hlc: const Hlc(1718020700000, 0),
        deleted: false,
        sig: '',
        content: const {'nickname': 'mira'},
      );

      const expected =
          '{"author":"$pub","created_at":1718020700000,"created_by":"$pub",'
          '"deleted":0,"hlc_counter":0,"hlc_ms":1718020700000,"id":"$pub",'
          '"nickname":"mira","t":"profile"}';

      expect(CanonicalSerializer.string(s), expected);
    });
  });

  group('round-trip', () {
    test('fromPayload(jsonDecode(string(s))) reconstructs the snapshot', () {
      final s = Snapshot(
        type: EntityType.card,
        id: 'card-rt',
        author: pub,
        createdBy: pub,
        createdAt: 1000,
        hlc: const Hlc(2000, 3),
        deleted: false,
        sig: '',
        placement: const Hlc(2500, 1),
        position: 'a3',
        content: const {
          'collection_id': 'col-1',
          'kind': 'text',
          'text': 'hi',
          'attachment_id': null,
          'settled_at': null,
        },
      );

      final back = Snapshot.fromPayload(
        jsonDecode(CanonicalSerializer.string(s)) as Map<String, Object?>,
      );

      expect(back.type, s.type);
      expect(back.id, s.id);
      expect(back.author, s.author);
      expect(back.createdBy, s.createdBy);
      expect(back.createdAt, s.createdAt);
      expect(back.hlc, s.hlc);
      expect(back.deleted, s.deleted);
      expect(back.placement, s.placement);
      expect(back.position, s.position);
      expect(back.content, s.content);
    });
  });

  group('§7.1 escaping rule 7', () {
    String titleEncoding(String title) {
      final s = Snapshot(
        type: EntityType.collection,
        id: 'c',
        author: pub,
        createdBy: pub,
        createdAt: 0,
        hlc: const Hlc(0, 0),
        deleted: false,
        sig: '',
        content: {
          'title': title,
          'description': null,
          'cover_attachment_id': null,
          'archived_at': null,
        },
      );
      final out = CanonicalSerializer.string(s);
      return RegExp(r'"title":(".*")\}$').firstMatch(out)!.group(1)!;
    }

    test(
      'escapes only what JSON requires; emits / < > & and non-ASCII verbatim',
      () {
        expect(titleEncoding('a"b'), r'"a\"b"');
        expect(titleEncoding(r'a\b'), r'"a\\b"');
        expect(titleEncoding('a\nb'), r'"a\nb"');
        expect(titleEncoding('a\tb'), r'"a\tb"');
        expect(titleEncoding('a\rb'), r'"a\rb"');
        expect(titleEncoding('</>&'), '"</>&"');
        expect(titleEncoding('café — ☕'), '"café — ☕"');
      },
    );

    test('control chars: short escapes, else lowercase backslash-u', () {
      expect(titleEncoding(String.fromCharCode(0x08)), r'"\b"');
      expect(titleEncoding(String.fromCharCode(0x0c)), r'"\f"');
      // 0x0b (vertical tab) and 0x1f (unit separator) have no short escape.
      expect(titleEncoding(String.fromCharCode(0x0b)), '"\\u000b"');
      expect(titleEncoding(String.fromCharCode(0x1f)), '"\\u001f"');
    });
  });

  group('field-set guard (§7.1 rule 4)', () {
    test('throws when a required field is missing (no silent omission)', () {
      final badCard = Snapshot(
        type: EntityType.card,
        id: 'x',
        author: pub,
        createdBy: pub,
        createdAt: 0,
        hlc: const Hlc(0, 0),
        deleted: false,
        sig: '',
        placement: const Hlc(0, 0),
        position: 'a0',
        // missing attachment_id
        content: const {'collection_id': 'c', 'kind': 'text', 'text': 't'},
      );
      expect(
        () => CanonicalSerializer.string(badCard),
        throwsA(isA<AssertionError>()),
      );
    });

    test('integers emit shortest-decimal', () {
      final s = Snapshot(
        type: EntityType.collection,
        id: 'c',
        author: pub,
        createdBy: pub,
        createdAt: 1718020800000,
        hlc: const Hlc(0, 0),
        deleted: false,
        sig: '',
        content: const {
          'title': 't',
          'description': null,
          'cover_attachment_id': null,
          'archived_at': null,
        },
      );
      expect(
        CanonicalSerializer.string(s),
        contains('"created_at":1718020800000'),
      );
      expect(CanonicalSerializer.string(s), contains('"hlc_ms":0'));
    });
  });
}
