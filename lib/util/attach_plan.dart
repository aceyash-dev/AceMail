/// The outcome of deciding which attachments fit.
typedef AttachPlan = ({List<int> accepted, int overSize, int overCount});

/// Decides which of [sizes] fit under [limit] bytes and [maxCount] files, given
/// [alreadyBytes] and [alreadyCount] already attached.
///
/// Sizes are **bytes**. Counting characters of a file path is not a size at
/// all, and a guard that measures the wrong thing is worse than none: it
/// reports a limit it is not enforcing.
///
/// Files are taken in order and skipped individually, so one oversized file
/// does not reject the smaller ones behind it.
///
/// The count is measured against what is **already** attached, not against this
/// selection alone. The picker caps each dialog, which meant picking ten files
/// three times was allowed — each dialog only ever saw its own ten.
AttachPlan planAttachments({
  required int alreadyBytes,
  required List<int> sizes,
  required int limit,
  int alreadyCount = 0,
  int maxCount = 0,
}) {
  final List<int> accepted = <int>[];
  int overSize = 0;
  int overCount = 0;
  int running = alreadyBytes < 0 ? 0 : alreadyBytes;
  int count = alreadyCount < 0 ? 0 : alreadyCount;

  for (int i = 0; i < sizes.length; i++) {
    final int size = sizes[i] < 0 ? 0 : sizes[i];
    if (maxCount > 0 && count + 1 > maxCount) {
      overCount++;
      continue;
    }
    if (running + size > limit) {
      overSize++;
      continue;
    }
    running += size;
    count++;
    accepted.add(i);
  }

  return (accepted: accepted, overSize: overSize, overCount: overCount);
}
