import 'package:hugeicons/hugeicons.dart';


/// An icon, as Hugeicons hands it over.
///
/// Hugeicons is a widget-based library: an icon is a list of SVG path
/// descriptions, not an `IconData`. That is why this is a list rather than a
/// font code point, and why the call sites build a `HugeIcon` rather than an
/// `Icon`.
typedef AceIcon = List<List<dynamic>>;

/// The app's icons, by meaning.
///
/// Nothing outside this file names a Hugeicons icon directly. That keeps the
/// choice in one place — if a name turns out to be the wrong shape, or the
/// library changes, one line moves rather than ninety call sites.
///
/// Hugeicons' free set is stroke-only, so there is no filled variant: a filled
/// star and an outline star are the same drawing, told apart by colour. That is
/// a real limitation of the set, not an oversight here.
abstract final class AceIcons {
  // --- mail and messages -------------------------------------------------
  static const AceIcon mail = HugeIcons.strokeRoundedMail01;
  static const AceIcon mailOpen = HugeIcons.strokeRoundedMailOpen01;
  static const AceIcon mailUnread = HugeIcons.strokeRoundedMail01;
  static const AceIcon inbox = HugeIcons.strokeRoundedInbox;
  static const AceIcon reply = HugeIcons.strokeRoundedMailReply01;
  static const AceIcon replyAll = HugeIcons.strokeRoundedMailReplyAll01;
  static const AceIcon send = HugeIcons.strokeRoundedSend;
  static const AceIcon archive = HugeIcons.strokeRoundedArchive01;
  static const AceIcon trash = HugeIcons.strokeRoundedDelete02;
  static const AceIcon star = HugeIcons.strokeRoundedStar;
  static const AceIcon folder = HugeIcons.strokeRoundedFolder01;
  static const AceIcon attachment = HugeIcons.strokeRoundedAttachment01;
  static const AceIcon at = HugeIcons.strokeRoundedAtSign;

  // --- actions -----------------------------------------------------------
  static const AceIcon search = HugeIcons.strokeRoundedSearch01;
  static const AceIcon restore = HugeIcons.strokeRoundedUndo;
  static const AceIcon deleteSweep = HugeIcons.strokeRoundedDelete02;
  static const AceIcon close = HugeIcons.strokeRoundedCancel01;
  static const AceIcon check = HugeIcons.strokeRoundedTick02;
  static const AceIcon checkCircle = HugeIcons.strokeRoundedCheckmarkCircle01;
  static const AceIcon add = HugeIcons.strokeRoundedPlusSign;
  static const AceIcon edit = HugeIcons.strokeRoundedEdit01;
  static const AceIcon copy = HugeIcons.strokeRoundedCopy01;
  static const AceIcon refresh = HugeIcons.strokeRoundedRefresh01;
  static const AceIcon filterOff = HugeIcons.strokeRoundedFilterRemove;
  static const AceIcon expandMore = HugeIcons.strokeRoundedChevronDown;
  static const AceIcon chevronLeft = HugeIcons.strokeRoundedChevronLeft;
  static const AceIcon chevronRight = HugeIcons.strokeRoundedChevronRight;
  static const AceIcon unfold = HugeIcons.strokeRoundedUnfoldMore;
  static const AceIcon list = HugeIcons.strokeRoundedLeftToRightListBullet;
  static const AceIcon menu = HugeIcons.strokeRoundedMenu01;

  /// The drawer toggle. A hamburger says "a menu"; this says "the sidebar",
  /// which is what it opens.
  static const AceIcon sidebar = HugeIcons.strokeRoundedSidebarLeft;

  // --- settings ----------------------------------------------------------
  static const AceIcon settings = HugeIcons.strokeRoundedSettings01;
  static const AceIcon palette = HugeIcons.strokeRoundedPalette;
  static const AceIcon density = HugeIcons.strokeRoundedLayoutList;
  static const AceIcon textSize = HugeIcons.strokeRoundedTextFont;
  static const AceIcon brightness = HugeIcons.strokeRoundedSun01;
  static const AceIcon image = HugeIcons.strokeRoundedImage01;
  static const AceIcon password = HugeIcons.strokeRoundedLockPassword;
  static const AceIcon signature = HugeIcons.strokeRoundedPencilEdit02;
  static const AceIcon headers = HugeIcons.strokeRoundedSourceCode;
  static const AceIcon account = HugeIcons.strokeRoundedUserCircle;
  static const AceIcon logout = HugeIcons.strokeRoundedLogout01;
  static const AceIcon visibility = HugeIcons.strokeRoundedEye;
  static const AceIcon visibilityOff = HugeIcons.strokeRoundedEyeOff;
  static const AceIcon reconnect = HugeIcons.strokeRoundedRefresh01;

  // --- gestures and sorting ---------------------------------------------
  static const AceIcon swipeRight = HugeIcons.strokeRoundedSwipeRight01;
  static const AceIcon swipeLeft = HugeIcons.strokeRoundedSwipeLeft01;
  static const AceIcon sort = HugeIcons.strokeRoundedSorting01;
  static const AceIcon sortNewest = HugeIcons.strokeRoundedSortByDown01;
  static const AceIcon sortOldest = HugeIcons.strokeRoundedSortByUp01;
  static const AceIcon sortSender = HugeIcons.strokeRoundedUser;
  static const AceIcon sortSubject = HugeIcons.strokeRoundedText;
  static const AceIcon sortUnread = HugeIcons.strokeRoundedMail01;

  // --- states and misc ---------------------------------------------------
  static const AceIcon info = HugeIcons.strokeRoundedInformationCircle;
  static const AceIcon help = HugeIcons.strokeRoundedHelpCircle;
  static const AceIcon error = HugeIcons.strokeRoundedAlertCircle;
  static const AceIcon warning = HugeIcons.strokeRoundedAlert02;
  static const AceIcon globe = HugeIcons.strokeRoundedGlobe;
  static const AceIcon cloud = HugeIcons.strokeRoundedCloud;
  static const AceIcon shield = HugeIcons.strokeRoundedShield01;
  static const AceIcon lock = HugeIcons.strokeRoundedLock;
  static const AceIcon fingerprint = HugeIcons.strokeRoundedFingerprintScan;
  /// The search bar's microphone.
  static const AceIcon mic = HugeIcons.strokeRoundedMic01;
  /// Chyme, the assistant.
  static const AceIcon chyme = HugeIcons.strokeRoundedAiBrain01;
  /// Writing with Chyme.
  static const AceIcon chymeWrite = HugeIcons.strokeRoundedAiContentGenerator01;
  static const AceIcon github = HugeIcons.strokeRoundedGithub;
  static const AceIcon openInNew = HugeIcons.strokeRoundedArrowUpRight01;
  static const AceIcon news = HugeIcons.strokeRoundedNews;

  /// The icon for a folder, from its role.
  static AceIcon forFolder(String name, {bool isInbox = false}) {
    final String key = name.toLowerCase();
    if (isInbox || key.contains('inbox')) return inbox;
    if (key.contains('sent')) return send;
    if (key.contains('draft')) return edit;
    if (key.contains('trash') || key.contains('deleted')) return trash;
    if (key.contains('archive') || key.contains('all mail')) return archive;
    if (key.contains('spam') || key.contains('junk')) return warning;
    return folder;
  }
}
