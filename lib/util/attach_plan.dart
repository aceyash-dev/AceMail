/// The outcome of deciding which attachments fit.
typedef AttachPlan = ({List<int> accepted, int rejected});

/// Decides which of [sizes] fit under [limit], given [alreadyBytes] in use.
///
/// Sizes are **bytes**. Counting characters of a file path is not a size at
/// all, and a guard that measures the wrong thing is worse than none: it
/// reports a limit it is not enforcing.
///
/// Files are taken in order and skipped individually, so one oversized file
/// does not reject the smaller ones behind it.
AttachPlan planAttachments({
  required int alreadyBytes,
  required List<int> sizes,
  required int limit,
}) {
  final List<int> accepted = <int>[];
  int rejected = 0;
  int running = alreadyBytes < 0 ? 0 : alreadyBytes;

  for (int i = 0; i < sizes.length; i++) {
    final int size = sizes[i] < 0 ? 0 : sizes[i];
    if (running + size > limit) {
      rejected++;
      continue;
    }
    running += size;
    accepted.add(i);
  }

  return (accepted: accepted, rejected: rejected);
}
