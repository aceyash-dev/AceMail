import 'package:ace_mail/services/request_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RequestQueue', () {
    test('runs operations in the order they were queued', () async {
      final RequestQueue queue = RequestQueue();
      final List<int> order = <int>[];

      // Deliberately different durations: without a queue, 3 would finish first.
      final List<Future<void>> pending = <Future<void>>[
        queue.run(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          order.add(1);
        }),
        queue.run(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          order.add(2);
        }),
        queue.run(() async => order.add(3)),
      ];
      await Future.wait(pending);

      expect(order, <int>[1, 2, 3]);
    });

    test('returns each operation result to its own caller', () async {
      final RequestQueue queue = RequestQueue();
      final List<Future<int>> results = <Future<int>>[
        queue.run(() async => 1),
        queue.run(() async => 2),
        queue.run(() async => 3),
      ];
      expect(await Future.wait(results), <int>[1, 2, 3]);
    });

    test('an error reaches its caller and does not stall the queue', () async {
      final RequestQueue queue = RequestQueue();

      final Future<void> failing =
          queue.run(() async => throw StateError('nope'));
      await expectLater(failing, throwsStateError);

      // The queue must still be usable afterwards.
      expect(await queue.run(() async => 'fine'), 'fine');
    });

    test('reports how much is outstanding', () async {
      final RequestQueue queue = RequestQueue();
      expect(queue.depth, 0);
      expect(queue.isBusy, isFalse);

      final Future<void> first = queue.run(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      final Future<void> second = queue.run(() async {});
      expect(queue.depth, 2);
      expect(queue.isBusy, isTrue);

      await Future.wait(<Future<void>>[first, second]);
      expect(queue.depth, 0);
      expect(queue.isBusy, isFalse);
    });
  });
}
