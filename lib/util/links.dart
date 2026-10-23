/// Which links this app will hand to the platform.
///
/// A policy, not a widget: the message renderer and the assistant's replies both
/// need it, and two copies of a rule about what is safe to open is one copy too
/// many.
library;

/// The only schemes Ace Mail will hand to the platform launcher. Everything
/// else — `javascript:`, `data:`, `file:`, `intent:`, and arbitrary app
/// schemes — is discarded. `mailto:` is a deliberate exception because this is
/// a mail client.
const Set<String> kAllowedLinkSchemes = <String>{'http', 'https', 'mailto'};

/// Whether [uri] may be handed to the platform. Pure, so the rule can be
/// asserted without a browser.
bool mayOpenLink(Uri uri) =>
    kAllowedLinkSchemes.contains(uri.scheme.toLowerCase());
