import 'package:effect_emitter/effect_emitter.dart';
import 'package:flutter_test/flutter_test.dart';

/// A tiny sealed effect family, standing in for a feature's `<F>UiEffect`.
sealed class _Effect {
  const _Effect();
}

class _Pop extends _Effect {
  const _Pop();
}

class _ShowError extends _Effect {
  const _ShowError(this.message);
  final String message;
}

void main() {
  group('EffectEmitter', () {
    test('push delivers the effect to the attached handler', () {
      final emitter = EffectEmitter<_Effect>();
      final received = <_Effect>[];
      emitter.attach(received.add);

      emitter.push(const _Pop());
      emitter.push(const _ShowError('boom'));

      expect(received, hasLength(2));
      expect(received[0], isA<_Pop>());
      expect((received[1] as _ShowError).message, 'boom');
    });

    test('push before any attach is a no-op (not buffered)', () {
      final emitter = EffectEmitter<_Effect>();
      // Nothing attached yet — must not throw and must not buffer.
      emitter.push(const _Pop());

      final received = <_Effect>[];
      emitter.attach(received.add);
      expect(received, isEmpty); // the earlier push was dropped, not replayed
    });

    test('detach stops delivery', () {
      final emitter = EffectEmitter<_Effect>();
      final received = <_Effect>[];
      emitter.attach(received.add);

      emitter.push(const _Pop());
      emitter.detach();
      emitter.push(const _ShowError('after detach'));

      expect(received, hasLength(1)); // only the pre-detach push landed
    });

    test('attach replaces the previous handler', () {
      final emitter = EffectEmitter<_Effect>();
      final first = <_Effect>[];
      final second = <_Effect>[];
      emitter.attach(first.add);
      emitter.attach(second.add);

      emitter.push(const _Pop());

      expect(first, isEmpty);
      expect(second, hasLength(1));
    });
  });
}
