import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

const apiBase = String.fromEnvironment('ACEMAIL_API_BASE_URL');
const googleClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const ink = Color(0xFF2B1B16);
const paper = Color(0xFFFFF4EA);
const orange = Color(0xFFC84A00);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AceMailWebApp());
}

class AceMailWebApp extends StatelessWidget {
  const AceMailWebApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AceMail', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: orange, surface: paper), scaffoldBackgroundColor: paper, fontFamily: 'Arial'),
    home: const WebmailHome(),
  );
}

class WebmailHome extends StatefulWidget {
  const WebmailHome({super.key});
  @override
  State<WebmailHome> createState() => _WebmailHomeState();
}

class _WebmailHomeState extends State<WebmailHome> {
  GoogleSignInAccount? _user;
  bool _busy = false;
  String? _error;
  List<dynamic> _accounts = [];
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _imapHost = TextEditingController(text: 'imap.gmail.com');
  final _smtpHost = TextEditingController(text: 'smtp.gmail.com');

  @override
  void initState() { super.initState(); _initGoogle(); }
  Future<void> _initGoogle() async {
    try {
      await GoogleSignIn.instance.initialize(clientId: googleClientId.isEmpty ? null : googleClientId);
      GoogleSignIn.instance.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          setState(() { _user = event.user; _error = null; });
          _exchangeToken(event.user);
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          setState(() { _user = null; _accounts = []; });
        }
      }, onError: (Object e) { if (mounted) setState(() => _error = 'Google sign-in failed. Check the web OAuth client configuration.'); });
      await GoogleSignIn.instance.attemptLightweightAuthentication();
    } catch (_) { if (mounted) setState(() => _error = 'Google sign-in could not initialize. Configure GOOGLE_WEB_CLIENT_ID in the web build.'); }
  }
  Future<void> _signIn() async {
    if (googleClientId.isEmpty) { setState(() => _error = 'Google sign-in is not configured for this build.'); return; }
    try { await GoogleSignIn.instance.authenticate(); }
    catch (_) { if (mounted) setState(() => _error = 'Google sign-in was cancelled or could not complete.'); }
  }
  Future<void> _exchangeToken(GoogleSignInAccount user) async {
    if (apiBase.isEmpty) { setState(() => _error = 'Backend is not configured. Set ACEMAIL_API_BASE_URL in the web build.'); return; }
    try {
      final auth = await user.authentication;
      final response = await http.post(Uri.parse('$apiBase/api/auth/google'), headers: {'Content-Type':'application/json'}, body: jsonEncode({'idToken': auth.idToken}));
      if (response.statusCode != 200) throw Exception('Authentication rejected');
      await _loadAccounts();
    } catch (_) { if (mounted) setState(() => _error = 'Could not authenticate with the AceMail server. Verify the backend URL and Google OAuth audience.'); }
  }
  Future<void> _loadAccounts() async {
    try { final r = await http.get(Uri.parse('$apiBase/api/accounts'), headers: await _headers()); if (r.statusCode == 200) setState(() => _accounts = jsonDecode(r.body) as List<dynamic>); else throw Exception(); }
    catch (_) { if (mounted) setState(() => _error = 'Could not load accounts. Check backend configuration.'); }
  }
  Future<Map<String,String>> _headers() async {
    final token = await _user?.authentication;
    return {'Content-Type':'application/json', if (token?.idToken != null) 'Authorization':'Bearer ${token!.idToken}'};
  }
  Future<void> _addAccount() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) { setState(() => _error = 'Enter the email address and provider app password.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      final r = await http.post(Uri.parse('$apiBase/api/accounts'), headers: await _headers(), body: jsonEncode({'email':_email.text.trim(),'password':_password.text,'imapHost':_imapHost.text.trim(),'imapPort':993,'smtpHost':_smtpHost.text.trim(),'smtpPort':465}));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception();
      _password.clear(); await _loadAccounts();
    } catch (_) { setState(() => _error = 'Account was not added. Check the server, credentials, and provider app-password requirements.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  void dispose() { _email.dispose(); _password.dispose(); _imapHost.dispose(); _smtpHost.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 760;
    return Scaffold(body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1120), child: Padding(padding: EdgeInsets.all(wide ? 32 : 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20), Row(children: [const Icon(Icons.mark_email_unread_outlined, size: 38, color: orange), const SizedBox(width: 12), const Expanded(child: Text('AceMail', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: ink, letterSpacing: -1.2))), if (_user != null) TextButton.icon(onPressed: () async { await GoogleSignIn.instance.signOut(); setState(() {_user = null; _accounts = [];}); }, icon: const Icon(Icons.logout), label: const Text('Sign out'))]),
      const Text('Your mail. Your providers. One calm inbox.', style: TextStyle(color: Color(0xFF806C61), fontSize: 15)), const SizedBox(height: 30),
      Expanded(child: _user == null ? _signInPanel() : _mailPanel(wide)),
      const Padding(padding: EdgeInsets.only(top: 12), child: Text('AceMail Web · Credentials must only be sent to your configured HTTPS backend.', style: TextStyle(fontSize: 12, color: Color(0xFF806C61))))
    ])))));
  }
  Widget _signInPanel() => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Card(color: Colors.white.withValues(alpha: .72), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: const BorderSide(color: Color(0xFFE9D1BE)),), child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.mark_email_unread_outlined, size: 56, color: orange), const SizedBox(height: 18), const Text('Email, without the noise.', textAlign: TextAlign.center, style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 8), const Text('Sign in to your AceMail web workspace, then connect the mailboxes you want to use.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF806C61), height: 1.5)), const SizedBox(height: 24), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _busy ? null : _signIn, icon: const Icon(Icons.g_mobiledata, size: 28), label: const Text('Continue with Google'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 17), foregroundColor: ink, side: const BorderSide(color: Color(0xFFE1C7B3)), shape: const StadiumBorder()))), if (_error != null) _errorBox(), const SizedBox(height: 10), const Text('Google sign-in identifies you to AceMail; it does not automatically grant mailbox access.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF806C61))) ])))));
  Widget _mailPanel(bool wide) => ListView(children: [Text('Welcome, ${_user?.displayName ?? _user?.email ?? 'there'}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 8), const Text('Connect an IMAP/SMTP mailbox using its provider app password. Never use your normal account password when your provider requires an app password.', style: TextStyle(color: Color(0xFF806C61), height: 1.5)), const SizedBox(height: 20), if (_error != null) _errorBox(), Card(color: Colors.white.withValues(alpha: .7), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFFE9D1BE))), child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Connect a mailbox', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)), const SizedBox(height: 16), _field(_email, 'Email address', Icons.alternate_email), const SizedBox(height: 12), _field(_password, 'Provider app password', Icons.key, secret: true), const SizedBox(height: 12), Row(children: [Expanded(child: _field(_imapHost, 'IMAP host', Icons.inbox_outlined)), const SizedBox(width: 12), Expanded(child: _field(_smtpHost, 'SMTP host', Icons.outgoing_mail))]), const SizedBox(height: 16), SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _addAccount, style: FilledButton.styleFrom(backgroundColor: orange, padding: const EdgeInsets.symmetric(vertical: 16)), child: Text(_busy ? 'Connecting…' : 'Add mailbox')))]))), const SizedBox(height: 24), const Text('Connected mailboxes', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)), const SizedBox(height: 10), if (_accounts.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(22), child: Text('No mailboxes connected yet.'))) else ..._accounts.map((a) => Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.mail_outline)), title: Text('${a['email'] ?? 'Mailbox'}'), subtitle: const Text('Connected mailbox'), trailing: const Icon(Icons.chevron_right)))), const SizedBox(height: 20), const Text('Inbox and sending APIs are enabled only after a secure backend is deployed and configured.', style: TextStyle(color: Color(0xFF806C61))) ]);
  Widget _field(TextEditingController c, String label, IconData icon, {bool secret = false}) => TextField(controller: c, obscureText: secret, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), filled: true, fillColor: const Color(0xFFFFE8D7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)));
  Widget _errorBox() => Container(margin: const EdgeInsets.only(top: 18), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFFFDEDB), borderRadius: BorderRadius.circular(16)), child: Text(_error!, style: const TextStyle(color: Color(0xFF8D2929))));
}
