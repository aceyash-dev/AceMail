import '../data/limits.dart';

/// The outcome of deciding which attachments fit.
typedef AttachPlan = ({List<int> accepted, int rejected});

/// Decides which of [sizes] fit under [limit], given [alreadyBytes] and
/// [alreadyCount] already in use.
///
/// Files that exceed the byte or count budget are skipped individually, so a
/// rejected file does not block smaller files behind it. Sizes are **bytes**. Counting characters of a file path is not a size at
/// all, and a guard that measures the wrong thing is worse than none: it
/// reports a limit it is not enforcing.
///
/// Files are taken in order and skipped individually, so one oversized file
/// does not reject the smaller ones behind it.
AttachPlan planAttachments({
  required int alreadyBytes,
  required List<int> sizes,
  required int limit,
  int alreadyCount = 0,
  int maxCount = MailLimits.maxAttachmentCount,
}) {
  final List<int> accepted = <int>[];
  int rejected = 0;
  int running = alreadyBytes < 0 ? 0 : alreadyBytes;

  for (int i = 0; i < sizes.length; i++) {
    final int size = sizes[i] < 0 ? 0 : sizes[i];
    if (alreadyCount + accepted.length >= maxCount || running + size > limit) {
      rejected++;
      continue;
    }
    running += size;
    accepted.add(i);
  }

  return (accepted: accepted, rejected: rejected);
}
