import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../data/mail_providers.dart';
import '../data/preferences.dart';
import '../models/ace_account.dart';
import '../models/sign_in_form.dart';
import '../state/mail_controller.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/routes.dart';
import '../widgets/ace_form_field.dart';
import '../widgets/advanced_server_panel.dart';
import '../widgets/astryx_widgets.dart';
import '../widgets/confirm_exit.dart';
import '../widgets/settings_group.dart';
import 'tutorial_screen.dart';

/// The app's front door, and the entry point for adding a second account.
///
/// In [isAdding] mode it sits on top of an existing session and can be
/// dismissed; otherwise back asks whether to quit.
///
/// Failures are shown in exactly one place — the inline box below the fields.
/// Validation problems and connection errors both land there, so a rejected
/// password does not look different depending on which layer rejected it.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.isAdding = false});

  /// True when this is a second (or third) account being added on top of an
  /// existing session, in which case the screen can be dismissed.
  final bool isAdding;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final SignInFormModel _form;

  /// The most recent validation failure. Cleared on the next attempt.
  String? _validationError;

  @override
  void initState() {
    super.initState();
    // Prefill the last address used, unless we are adding a second account.
    _form = SignInFormModel(
      initialEmail: widget.isAdding
          ? ''
          : (context.read<MailController>().lastEmail ?? ''),
    );
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final SignInOutcome outcome = _form.build();
    setState(() {
      _validationError = outcome.error;
      if (outcome.needsAdvanced) _form.advanced = true;
    });

    final AceAccount? account = outcome.account;
    if (account == null) return;

    final bool ok =
        await context.read<MailController>().signIn(account, _form.password.text);
    if (!mounted) return;
    if (ok) {
      TextInput.finishAutofillContext();
      if (widget.isAdding) Navigator.of(context).pop();
    }
  }

  void _openTutorial() {
    Navigator.of(context).push(aceRoute(const TutorialScreen()));
  }

  Future<void> _handleBack() async {
    if (widget.isAdding) {
      Navigator.of(context).pop();
      return;
    }
    // The user can turn the confirmation off; then leaving just leaves.
    final Preferences prefs = context.read<Preferences>();
    if (prefs.confirmExit && !await confirmExit(context)) return;
    if (!mounted) return;
    final NavigatorState nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final MailController controller = context.watch<MailController>();
    final bool connecting = controller.connecting;
    final String? error = _validationError ?? controller.errorMessage;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: <Color>[c.accentMuted, c.backgroundBody, c.backgroundMuted],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AstryxSpace.s5),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext context, double t, Widget? child) =>
                      Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 14),
                      child: child,
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AceSurface(
                      radius: AstryxRadius.page,
                      padding: const EdgeInsets.all(AstryxSpace.s7),
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _header(context, c),
                            const SizedBox(height: AstryxSpace.s6),
                            // The address, as two halves. Most people know
                            // their username; almost nobody wants to type the
                            // domain, and picking it is what fills the IMAP and
                            // SMTP servers in.
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  flex: 3,
                                  child: AceFormField(
                                    label: 'Username',
                                    controller: _form.username,
                                    hint: 'you',
                                    keyboard: TextInputType.emailAddress,
                                    autofillHints: const <String>[
                                      AutofillHints.username,
                                      AutofillHints.email,
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AstryxSpace.s3),
                                Expanded(
                                  flex: 4,
                                  child: _DomainField(
                                    form: _form,
                                    onChanged: () => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AstryxSpace.s4),
                            AcePasswordField(
                              label: 'Password / app password',
                              controller: _form.password,
                              obscure: _form.obscure,
                              autofillHints: const <String>[
                                AutofillHints.password,
                              ],
                              onToggleObscure: () => setState(
                                () => _form.obscure = !_form.obscure,
                              ),
                            ),
                            const SizedBox(height: AstryxSpace.s3),
                            AdvancedServerPanel(
                              form: _form,
                              onToggle: () => setState(
                                () => _form.advanced = !_form.advanced,
                              ),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: error == null
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                      padding: const EdgeInsets.only(
                                        top: AstryxSpace.s4,
                                      ),
                                      child: AceErrorBox(
                                        message: error,
                                        action: AceButton(
                                          label: 'How to fix this',
                                          icon: AceIcons.help,
                                          onPressed: _openTutorial,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: AstryxSpace.s5),
                            AceButton(
                              label: connecting ? 'Connecting…' : 'Connect',
                              variant: AceButtonVariant.primary,
                              size: AceButtonSize.large,
                              loading: connecting,
                              expand: true,
                              onPressed: connecting ? null : _submit,
                            ),
                            const SizedBox(height: AstryxSpace.s4),
                            Text(
                              'Gmail, Yahoo and iCloud need an app password, not '
                              'your normal login. Your password is stored in this '
                              'device\'s keychain and sent only to your provider.',
                              style: AstryxText.supporting(c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AstryxColors c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const BrandMark(),
        const SizedBox(width: AstryxSpace.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Ace Mail', style: AstryxText.display3(c.textPrimary)),
              const SizedBox(height: AstryxSpace.s0_5),
              Text(
                widget.isAdding
                    ? 'Add another account'
                    : 'Any IMAP · any SMTP · any device',
                style: AstryxText.body(c.textSecondary),
              ),
            ],
          ),
        ),
        AceIconButton(
          icon: AceIcons.help,
          tooltip: 'How to sign in',
          onPressed: _openTutorial,
        ),
        if (widget.isAdding)
          AceIconButton(
            icon: AceIcons.close,
            tooltip: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
      ],
    );
  }
}

/// The domain half of the address: a picker for the providers we know, and a
/// plain field for anything else.
///
/// Picking a known domain is what fills in the IMAP and SMTP servers, so the
/// common case never opens the advanced panel at all.
class _DomainField extends StatelessWidget {
  const _DomainField({required this.form, required this.onChanged});

  final SignInFormModel form;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (form.customDomain) {
      return AceFormField(
        label: 'Domain',
        controller: form.domainField,
        hint: 'example.com',
        keyboard: TextInputType.url,
        trailing: IconButton(
          icon: const HugeIcon(icon: AceIcons.list, size: 20),
          tooltip: 'Pick a provider',
          onPressed: () => _pick(context),
        ),
      );
    }

    final AstryxColors c = context.astryx;

    return AceFormField(
      label: 'Domain',
      controller: TextEditingController(text: '@${form.domain}'),
      readOnly: true,
      onTap: () => _pick(context),
      trailing: AceIconButton(
        icon: AceIcons.expandMore,
        tooltip: 'Choose a domain',
        onPressed: () => _pick(context),
      ),
      hint: '',
      keyboard: TextInputType.none,
      background: c.backgroundMuted,
    );
  }

  Future<void> _pick(BuildContext context) async {
    final String? chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: AstryxSpace.s4),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AstryxSpace.s5,
                0,
                AstryxSpace.s5,
                AstryxSpace.s3,
              ),
              child: Text(
                'Your mail provider',
                style: AstryxText.heading3(sheetContext.astryx.textPrimary),
              ),
            ),
            for (final MailProvider provider in kProviderChoices)
              SettingsRow(
                icon: AceIcons.at,
                title: provider.label,
                subtitle: provider.domains.first,
                trailing: provider.domains.first == form.domain
                    ? HugeIcon(icon: 
                        AceIcons.check,
                        size: 20,
                        color: sheetContext.astryx.accent,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(provider.domains.first),
              ),
            const Divider(height: 1),
            SettingsRow(
              icon: AceIcons.edit,
              title: 'Other',
              subtitle: 'Type your own domain and servers',
              onTap: () => Navigator.of(sheetContext).pop(_kCustomDomain),
            ),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    if (chosen == _kCustomDomain) {
      form.customDomain = true;
      form.advanced = true;
    } else {
      form.customDomain = false;
      form.domain = chosen;
      // Selecting a domain fills the servers from the table.
      form.applyProvider();
    }
    onChanged();
  }
}

/// Marks the "type your own" row, which is not a domain.
const String _kCustomDomain = '\u0000custom';
