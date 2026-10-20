import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/mail_providers.dart';
import '../models/ace_account.dart';
import '../state/mail_controller.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/routes.dart';
import '../widgets/astryx_widgets.dart';
import 'tutorial_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.isAdding = false});

  /// True when this is a second (or third) account being added on top of an
  /// existing session, in which case the screen can be dismissed.
  final bool isAdding;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _imapHost = TextEditingController();
  final TextEditingController _imapPort = TextEditingController(text: '993');
  final TextEditingController _smtpHost = TextEditingController();
  final TextEditingController _smtpPort = TextEditingController(text: '587');

  bool _advanced = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Prefill the last address used, unless we are adding a second account.
    final String? last = context.read<MailController>().lastEmail;
    if (!widget.isAdding && last != null) {
      _email.text = last;
      _autofill();
    }
    _email.addListener(_autofill);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _imapHost.dispose();
    _imapPort.dispose();
    _smtpHost.dispose();
    _smtpPort.dispose();
    super.dispose();
  }

  void _autofill() {
    final MailServer? server = serverForEmail(_email.text);
    if (server == null) return;
    setState(() {
      _imapHost.text = server.imapHost;
      _imapPort.text = '${server.imapPort}';
      _smtpHost.text = server.smtpHost;
      _smtpPort.text = '${server.smtpPort}';
    });
  }

  Future<void> _submit() async {
    final MailController controller = context.read<MailController>();
    final String email = _email.text.trim();

    if (!email.contains('@')) {
      await _fail('Enter a valid email address.');
      return;
    }
    if (_password.text.isEmpty) {
      await _fail('Enter your password.');
      return;
    }
    if (_imapHost.text.trim().isEmpty || _smtpHost.text.trim().isEmpty) {
      setState(() => _advanced = true);
      await _fail('Enter the IMAP and SMTP servers for your provider.');
      return;
    }

    final AceAccount account = AceAccount(
      email: email,
      imapHost: _imapHost.text.trim(),
      imapPort: int.tryParse(_imapPort.text.trim()) ?? 993,
      smtpHost: _smtpHost.text.trim(),
      smtpPort: int.tryParse(_smtpPort.text.trim()) ?? 587,
    );

    final bool ok = await controller.signIn(account, _password.text);
    if (!mounted) return;
    if (ok) {
      TextInput.finishAutofillContext();
      if (widget.isAdding) Navigator.of(context).pop();
    }
  }

  void _openTutorial() {
    Navigator.of(context).push(aceRoute(const TutorialScreen()));
  }

  Future<void> _fail(String message) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Check the details'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return Future<void>.value();
  }

  Future<void> _handleBack() async {
    if (widget.isAdding) {
      Navigator.of(context).pop();
      return;
    }
    final bool leave = await _confirmExit();
    if (!leave || !mounted) return;
    final NavigatorState nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      await SystemNavigator.pop();
    }
  }

  Future<bool> _confirmExit() async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Exit Ace Mail?'),
        content: const Text('Ace Mail will close.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final MailController controller = context.watch<MailController>();
    final bool connecting = controller.connecting;

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
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const BrandMark(),
                                const SizedBox(width: AstryxSpace.s4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'Ace Mail',
                                        style: AstryxText.heading1(
                                          c.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        widget.isAdding
                                            ? 'Add another account'
                                            : 'Any IMAP · any SMTP · any device',
                                        style: AstryxText.supporting(
                                          c.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AceIconButton(
                                  icon: Icons.help_outline_rounded,
                                  tooltip: 'How to sign in',
                                  onPressed: _openTutorial,
                                ),
                                if (widget.isAdding)
                                  AceIconButton(
                                    icon: Icons.close_rounded,
                                    tooltip: 'Cancel',
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AstryxSpace.s6),
                            _field(
                              'Email address',
                              _email,
                              hint: 'you@example.com',
                              keyboard: TextInputType.emailAddress,
                              autofillHints: const <String>[AutofillHints.email],
                            ),
                            const SizedBox(height: AstryxSpace.s4),
                            _passwordField(c),
                            const SizedBox(height: AstryxSpace.s3),
                            _advancedToggle(c),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: _advanced
                                  ? _advancedPanel(c)
                                  : const SizedBox(width: double.infinity),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: controller.errorMessage == null
                                  ? const SizedBox(width: double.infinity)
                                  : _errorBox(c, controller.errorMessage!),
                            ),
                            const SizedBox(height: AstryxSpace.s5),
                            AceButton(
                              label: connecting ? 'Connecting…' : 'Connect',
                              variant: AceButtonVariant.primary,
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

  Widget _advancedToggle(AstryxColors c) {
    return InkWell(
      onTap: () => setState(() => _advanced = !_advanced),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AstryxSpace.s1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedRotation(
              turns: _advanced ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_right_rounded,
                size: 18,
                color: c.textAccent,
              ),
            ),
            const SizedBox(width: AstryxSpace.s1),
            Text(
              'Advanced server settings',
              style: AstryxText.label(c.textAccent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _advancedPanel(AstryxColors c) {
    return Padding(
      padding: const EdgeInsets.only(top: AstryxSpace.s3),
      child: AceSurface(
        color: c.backgroundMuted,
        padding: const EdgeInsets.all(AstryxSpace.s4),
        child: Column(
          children: <Widget>[
            _field('IMAP host', _imapHost, hint: 'imap.example.com'),
            const SizedBox(height: AstryxSpace.s3),
            Row(
              children: <Widget>[
                Expanded(child: _field('IMAP port', _imapPort)),
                const SizedBox(width: AstryxSpace.s3),
                Expanded(child: _field('SMTP port', _smtpPort)),
              ],
            ),
            const SizedBox(height: AstryxSpace.s3),
            _field('SMTP host', _smtpHost, hint: 'smtp.example.com'),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(AstryxColors c, String message) {
    return Padding(
      padding: const EdgeInsets.only(top: AstryxSpace.s4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AstryxSpace.s3),
        decoration: BoxDecoration(
          color: c.errorMuted,
          borderRadius: BorderRadius.circular(AstryxRadius.element),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(message, style: AstryxText.supporting(c.error)),
            const SizedBox(height: AstryxSpace.s3),
            AceButton(
              label: 'How to fix this',
              icon: Icons.help_outline_rounded,
              onPressed: _openTutorial,
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordField(AstryxColors c) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _field(
            'Password / app password',
            _password,
            obscure: _obscure,
            autofillHints: const <String>[AutofillHints.password],
          ),
        ),
        const SizedBox(width: AstryxSpace.s2),
        AceIconButton(
          icon: _obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          tooltip: _obscure ? 'Show' : 'Hide',
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    bool obscure = false,
    TextInputType? keyboard,
    List<String>? autofillHints,
  }) {
    final AstryxColors c = context.astryx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AstryxText.label(c.textSecondary)),
        const SizedBox(height: AstryxSpace.s1_5),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          autofillHints: autofillHints,
          style: AstryxText.body(c.textPrimary),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
