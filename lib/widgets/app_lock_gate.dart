import 'dart:async';

import 'package:flutter/material.dart';

import '../services/contacts.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../services/app_lock.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import 'ace_icon_view.dart';
import 'astryx_widgets.dart';

/// Covers the app until the device says who is holding it.
///
/// A lock that only runs at launch is not much of a lock. The interesting
/// moment is *coming back* to an app that was left open, which is exactly when
/// somebody else is holding the phone — so this covers the app on the way out
/// as well as on the way in.
///
/// The cover is drawn over the app rather than replacing it: unlocking then
/// costs one frame instead of a rebuild of every screen, and nothing behind it
/// is readable or tappable while it is up.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _locked = false;
  bool _asking = false;

  /// Whether this device can ask at all. Null until it has been asked once.
  bool? _canAuthenticate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = context.read<Preferences>().appLock;
    if (_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app is the moment to write anything the contact book is
    // holding: its writes are debounced, and a debounce that never fires is a
    // page of addresses learned and lost.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(Contacts.flush());
    }
    // `paused` and `hidden` only. `inactive` also fires for the app switcher and
    // for system dialogs — including the authentication prompt itself — and
    // locking on it would put the cover up in the middle of unlocking.
    if (state != AppLifecycleState.paused && state != AppLifecycleState.hidden) {
      return;
    }
    if (!mounted) return;
    if (_canAuthenticate == false) return; // nothing to lock behind
    if (context.read<Preferences>().appLock && !_locked) {
      // On the way out, so the cover is already up when the app comes back —
      // rather than the inbox showing for a frame first.
      setState(() => _locked = true);
    }
  }

  /// Whether the device can ask for a fingerprint or a face.
  ///
  /// Asked once and remembered. A device that cannot ask must not hold the door
  /// shut: locking somebody out of their own mail because their phone has no
  /// enrolled biometrics is a worse failure than the lock not engaging, so an
  /// impossible lock is not a lock.
  Future<bool> _canAsk() async =>
      _canAuthenticate ??= await AppLock.available();

  Future<void> _ask() async {
    if (_asking) return;
    setState(() => _asking = true);

    final bool possible = await _canAsk();
    final bool ok = possible && await AppLock.unlock();

    if (!mounted) return;
    setState(() {
      _asking = false;
      if (ok || !possible) _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Read live, so turning the setting off drops the cover at once. Turning it
    // on takes effect on the next pause or launch, which the setting says.
    final bool locked = _locked && context.watch<Preferences>().appLock;

    return Stack(
      children: <Widget>[
        ExcludeSemantics(
          excluding: locked,
          child: IgnorePointer(ignoring: locked, child: widget.child),
        ),
        if (locked) Positioned.fill(child: _Cover(onUnlock: _ask)),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return ColoredBox(
      color: c.backgroundBody,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AstryxSpace.s8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: c.accentMuted,
                    borderRadius: BorderRadius.circular(AstryxRadius.container),
                  ),
                  child: Center(
                    child: AceIconView(
                      icon: AceIcons.lock,
                      size: 30,
                      color: c.onAccentMuted,
                    ),
                  ),
                ),
                const SizedBox(height: AstryxSpace.s6),
                Text(
                  'Ace Mail is locked',
                  style: AstryxText.heading2(c.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AstryxSpace.s2),
                Text(
                  'Unlock to read your mail.',
                  style: AstryxText.body(c.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AstryxSpace.s6),
                AceButton(
                  label: 'Unlock',
                  icon: AceIcons.fingerprint,
                  onPressed: onUnlock,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
