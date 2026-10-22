import 'package:ace_mail/util/attach_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('planAttachments', () {
    test('takes everything that fits', () {
      final AttachPlan plan = planAttachments(
        alreadyBytes: 0,
        sizes: <int>[100, 200, 300],
        limit: 1000,
      );
      expect(plan.accepted, <int>[0, 1, 2]);
      expect(plan.overSize, 0);
      expect(plan.overCount, 0);
    });

    test('counts the bytes already attached', () {
      final AttachPlan plan = planAttachments(
        alreadyBytes: 900,
        sizes: <int>[50, 200],
        limit: 1000,
      );
      expect(plan.accepted, <int>[0]);
      expect(plan.overSize, 1);
    });

    test('skips one oversized file without rejecting the ones behind it', () {
      final AttachPlan plan = planAttachments(
        alreadyBytes: 0,
        sizes: <int>[10, 5000, 20],
        limit: 100,
      );
      expect(plan.accepted, <int>[0, 2]);
      expect(plan.overSize, 1);
    });

    test('the reported case: a 30 MB file keeps the 1 MB file behind it', () {
      // photo.png 2 MiB, video.mp4 30 MiB, notes.pdf 1 MiB, at a 25 MiB cap.
      // The video is left off; the PDF is not, which is the bug that was filed.
      const int mib = 1024 * 1024;
      final AttachPlan plan = planAttachments(
        alreadyBytes: 0,
        sizes: <int>[2 * mib, 30 * mib, 1 * mib],
        limit: 25 * mib,
      );
      expect(plan.accepted, <int>[0, 2]);
      expect(plan.overSize, 1);
    });

    test('a file exactly at the limit still fits', () {
      final AttachPlan plan = planAttachments(
        alreadyBytes: 0,
        sizes: <int>[100],
        limit: 100,
      );
      expect(plan.accepted, <int>[0]);
    });

    test('an empty selection is fine', () {
      final AttachPlan plan =
          planAttachments(alreadyBytes: 0, sizes: <int>[], limit: 100);
      expect(plan.accepted, isEmpty);
      expect(plan.overSize, 0);
      expect(plan.overCount, 0);
    });

    test('a negative running total is treated as zero, not as credit', () {
      final AttachPlan plan = planAttachments(
        alreadyBytes: -500,
        sizes: <int>[100],
        limit: 100,
      );
      expect(plan.accepted, <int>[0]);
    });

    test('sizes are bytes: 25 MB of characters is not 25 MB', () {
      // The old guard summed `path.length`, so a short path to a huge file
      // looked small. A real 30 MB file must be refused at a 25 MB limit.
      const int thirtyMb = 30 * 1024 * 1024;
      final AttachPlan plan = planAttachments(
        alreadyBytes: 0,
        sizes: <int>[thirtyMb],
        limit: 25 * 1024 * 1024,
      );
      expect(plan.accepted, isEmpty);
      expect(plan.overSize, 1);
    });

    group('the file count', () {
      test('is measured against what the message already carries', () {
        // Ten files three times used to be allowed: each dialog only ever saw
        // its own ten, and the planner only checked bytes.
        final AttachPlan plan = planAttachments(
          alreadyBytes: 0,
          alreadyCount: 9,
          sizes: <int>[1, 1, 1],
          limit: 1000,
          maxCount: 10,
        );
        expect(plan.accepted, <int>[0]);
        expect(plan.overCount, 2);
      });

      test('a full message takes nothing more', () {
        final AttachPlan plan = planAttachments(
          alreadyBytes: 0,
          alreadyCount: 10,
          sizes: <int>[1, 1],
          limit: 1000,
          maxCount: 10,
        );
        expect(plan.accepted, isEmpty);
        expect(plan.overCount, 2);
      });

      test('a size refusal is not counted as a count refusal', () {
        final AttachPlan plan = planAttachments(
          alreadyBytes: 0,
          alreadyCount: 0,
          sizes: <int>[5000, 10],
          limit: 100,
          maxCount: 10,
        );
        expect(plan.accepted, <int>[1]);
        expect(plan.overSize, 1);
        expect(plan.overCount, 0);
      });

      test('zero means no count limit', () {
        final AttachPlan plan = planAttachments(
          alreadyBytes: 0,
          alreadyCount: 500,
          sizes: <int>[1],
          limit: 1000,
        );
        expect(plan.accepted, <int>[0]);
      });
    });
  });
}
