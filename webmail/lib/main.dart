import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

const _apiBase = String.fromEnvironment('ACEMAIL_API_BASE_URL');
const _googleClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const _ink = Color(0xFF2B1B16);
const _paper = Color(0xFFFFF8F0);
const _orange = Color(0xFFC84A00);
const _line = Color(0xFFE8D4C1);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AceMailWebApp());
}

class AceMailWebApp extends StatelessWidget {
  const AceMailWebApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AceMail',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: _paper,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _orange,
            surface: _paper,
            brightness: Brightness.light,
          ),
          fontFamily: 'Arial',
          appBarTheme: const AppBarTheme(
            backgroundColor: _paper,
            foregroundColor: _ink,
            elevation: 0,
            centerTitle: false,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFFFEFE0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _orange, width: 1.5),
            ),
          ),
        ),
        home: const WebmailHome(),
      );
}

class WebmailHome extends StatefulWidget {
  const WebmailHome({super.key});

  @override
  State<WebmailHome> createState() => _WebmailHomeState();
}

class _WebmailHomeState extends State<WebmailHome> {
  final GoogleSignIn _google = GoogleSignIn.instance;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;
  GoogleSignInAccount? _user;
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _folders = [];
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _selectedMessage;
  String? _accountId;
  String _folder = 'INBOX';
  String? _error;
  bool _busy = false;
  bool _initialized = false;
  bool _loadingMessages = false;
  bool _showCompose = false;

  bool get _apiConfigured => _apiBase.startsWith('https://');
  Map<String, dynamic>? get _activeAccount {
    for (final account in _accounts) {
      if (account['id'] == _accountId) return account;
    }
    return _accounts.isEmpty ? null : _accounts.first;
  }

  @override
  void initState() {
    super.initState();
    _initializeGoogle();
  }

  Future<void> _initializeGoogle() async {
    try {
      await _google.initialize(
        clientId: _googleClientId.isEmpty ? null : _googleClientId,
      );
      _authSubscription = _google.authenticationEvents.listen(
        (event) async {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            if (!mounted) return;
            setState(() {
              _user = event.user;
              _error = null;
            });
            await _exchangeGoogleToken(event.user);
          } else if (event is GoogleSignInAuthenticationEventSignOut) {
            if (!mounted) return;
            setState(() {
              _user = null;
              _accounts = [];
              _folders = [];
              _messages = [];
              _selectedMessage = null;
              _accountId = null;
            });
          }
        },
        onError: (Object error) {
          if (mounted) setState(() => _error = 'Google sign-in failed. Check the Web OAuth client configuration.');
        },
      );
      await _google.attemptLightweightAuthentication();
    } catch (_) {
      if (mounted) {
        setState(() => _error = _googleClientId.isEmpty
            ? 'Google sign-in is not configured. Add GOOGLE_WEB_CLIENT_ID to the Vercel project environment.'
            : 'Google sign-in could not initialize. Verify the OAuth Web client and authorized JavaScript origins.');
      }
    } finally {
      if (mounted) setState(() => _initialized = true);
    }
  }

  Future<void> _signIn() async {
    if (_googleClientId.isEmpty) {
      setState(() => _error = 'Google sign-in is not configured for this deployment.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _google.authenticate();
    } catch (_) {
      if (mounted) setState(() => _error = 'Sign-in was cancelled or Google could not complete authentication.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _idToken() async {
    final user = _user;
    if (user == null) throw Exception('Sign in to continue.');
    final authentication = await user.authentication;
    final token = authentication.idToken;
    if (token == null || token.isEmpty) throw Exception('Google did not return an ID token. Check your Web OAuth client.');
    return token;
  }

  Future<Map<String, String>> _headers() async => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await _idToken()}',
      };

  Future<dynamic> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    if (!_apiConfigured) throw Exception('The mail API is not configured. Set ACEMAIL_API_BASE_URL to the deployed HTTPS API URL.');
    final uri = Uri.parse('${_apiBase.replaceFirst(RegExp(r'/+$'), '')}$path');
    final headers = await _headers();
    late http.Response response;
    switch (method) {
      case 'POST':
        response = await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 35));
      case 'DELETE':
        response = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 35));
      default:
        response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 35));
    }
    dynamic data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      throw Exception('The mail server returned an invalid response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map ? data['error']?.toString() : null;
      throw Exception(message?.isNotEmpty == true ? message! : 'Request failed (${response.statusCode}).');
    }
    return data;
  }

  Future<void> _exchangeGoogleToken(GoogleSignInAccount user) async {
    try {
      await _request('/api/auth/google', method: 'POST', body: {'idToken': await _idToken()});
      await _loadAccounts();
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    }
  }

  String _cleanError(Object error) => error.toString().replaceFirst('Exception: ', '');

  Future<void> _loadAccounts() async {
    try {
      final result = await _request('/api/accounts');
      final rows = (result as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (!mounted) return;
      setState(() {
        _accounts = rows;
        if (!_accounts.any((a) => a['id'] == _accountId)) {
          _accountId = _accounts.isEmpty ? null : _accounts.first['id']?.toString();
        }
        _error = null;
      });
      if (_accountId != null) await _loadFolders();
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    }
  }

  Future<void> _loadFolders() async {
    final id = _accountId;
    if (id == null) return;
    try {
      final result = await _request('/api/accounts/$id/folders');
      final rows = (result as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (!mounted) return;
      setState(() {
        _folders = rows;
        if (_folders.isNotEmpty && !_folders.any((f) => f['path'] == _folder)) {
          final inbox = _folders.where((f) => f['specialUse'] == '\\Inbox' || f['path'] == 'INBOX');
          _folder = inbox.isNotEmpty ? inbox.first['path'].toString() : _folders.first['path'].toString();
        }
      });
      await _loadMessages();
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    }
  }

  Future<void> _loadMessages() async {
    final id = _accountId;
    if (id == null) return;
    setState(() {
      _loadingMessages = true;
      _error = null;
      _selectedMessage = null;
    });
    try {
      final result = await _request('/api/accounts/$id/messages?folder=${Uri.encodeQueryComponent(_folder)}&limit=40');
      if (!mounted) return;
      setState(() => _messages = (result as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _loadingMessages = false);
    }
  }

  Future<void> _openMessage(Map<String, dynamic> message) async {
    final id = _accountId;
    if (id == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final uid = message['uid'];
      final result = await _request('/api/accounts/$id/messages/$uid?folder=${Uri.encodeQueryComponent(_folder)}');
      if (mounted) setState(() => _selectedMessage = Map<String, dynamic>.from(result as Map));
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectAccount({
    required String email,
    required String password,
    required String imapHost,
    required String smtpHost,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _request('/api/accounts', method: 'POST', body: {
        'email': email.trim(),
        'password': password,
        'imapHost': imapHost.trim(),
        'imapPort': 993,
        'smtpHost': smtpHost.trim(),
        'smtpPort': 465,
      });
      if (mounted) setState(() => _accountId = (result as Map)['id']?.toString());
      await _loadAccounts();
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeAccount(Map<String, dynamic> account) async {
    final id = account['id']?.toString();
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove mailbox?'),
        content: Text('Remove ${account['email']} and its encrypted saved settings from AceMail? This does not delete messages from your provider.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _request('/api/accounts/$id', method: 'DELETE');
      if (!mounted) return;
      setState(() {
        _accounts.removeWhere((a) => a['id'] == id);
        _accountId = _accounts.isEmpty ? null : _accounts.first['id']?.toString();
        _folders = [];
        _messages = [];
        _selectedMessage = null;
      });
      if (_accountId != null) await _loadFolders();
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    }
  }

  Future<void> _sendMessage(String to, String subject, String text) async {
    final id = _accountId;
    if (id == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _request('/api/accounts/$id/send', method: 'POST', body: {'to': to, 'subject': subject, 'text': text});
      if (mounted) {
        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message sent.')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.mark_email_unread_outlined, color: _orange, size: 30),
            SizedBox(width: 10),
            Text('AceMail', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1)),
          ],
        ),
        actions: [
          if (_user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Refresh mailbox',
                onPressed: _busy ? null : _loadFolders,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          if (_user != null)
            PopupMenuButton<String>(
              tooltip: 'Account options',
              onSelected: (value) async {
                if (value == 'signout') await _google.signOut();
                if (value == 'add') _showAddAccount();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'add', child: const Text('Add another mailbox')),
                PopupMenuItem(value: 'signout', child: Text('Sign out ${_user?.email ?? ''}')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: CircleAvatar(
                  backgroundColor: const Color(0xFFF2D8C3),
                  backgroundImage: _user?.photoUrl == null ? null : NetworkImage(_user!.photoUrl!),
                  child: _user?.photoUrl == null ? const Icon(Icons.person_outline, color: _ink) : null,
                ),
              ),
            ),
        ],
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : _user == null
              ? _signInScreen()
              : _accounts.isEmpty
                  ? _emptyMailboxScreen()
                  : _mailWorkspace(wide),
      floatingActionButton: _user != null && _accounts.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _showCompose,
              backgroundColor: _orange,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Compose'),
            )
          : null,
    );
  }

  Widget _signInScreen() => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              color: Colors.white.withValues(alpha: .8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: const BorderSide(color: _line)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mark_email_unread_outlined, size: 64, color: _orange),
                    const SizedBox(height: 16),
                    const Text('Your mail. Your providers.', textAlign: TextAlign.center, style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -1)),
                    const SizedBox(height: 10),
                    const Text('One calm inbox for the IMAP and SMTP accounts you choose to connect.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF806C61), height: 1.5)),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _signIn,
                        icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                        label: Text(_busy ? 'Connecting…' : 'Continue with Google'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _ink,
                          side: const BorderSide(color: _line),
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 18),
                      _errorCard(_error!),
                    ],
                    const SizedBox(height: 18),
                    const Text('Google identifies your AceMail workspace. It does not grant mailbox access by itself.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF806C61), height: 1.5)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _emptyMailboxScreen() => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Card(
              color: Colors.white.withValues(alpha: .75),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: const BorderSide(color: _line)),
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inbox_outlined, size: 56, color: _orange),
                    const SizedBox(height: 14),
                    Text('Welcome, ${_user?.displayName ?? _user?.email ?? 'there'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _ink)),
                    const SizedBox(height: 8),
                    const Text('Connect a mailbox using its provider app password. Your credentials are sent only to the configured HTTPS API and encrypted at rest.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF806C61), height: 1.5)),
                    const SizedBox(height: 24),
                    FilledButton.icon(onPressed: _busy ? null : _showAddAccount, icon: const Icon(Icons.add), label: const Text('Connect a mailbox'), style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16))),
                    if (_error != null) ...[const SizedBox(height: 18), _errorCard(_error!)],
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _mailWorkspace(bool wide) {
    final account = _activeAccount;
    final message = _selectedMessage;
    return Column(
      children: [
        if (_error != null)
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: _errorCard(_error!)),
        Expanded(
          child: wide
              ? Row(
                  children: [
                    SizedBox(width: 260, child: _sidebar()),
                    const VerticalDivider(width: 1, color: _line),
                    Expanded(child: message == null ? _messageList() : _messageReader(message)),
                  ],
                )
              : message != null
                  ? _messageReader(message)
                  : Column(
                      children: [
                        _mobileMailboxSelector(account),
                        Expanded(child: _messageList()),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _sidebar() => Container(
        color: const Color(0xFFFFF2E6),
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _showCompose,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Compose'),
              style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              value: _accountId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Mailbox', prefixIcon: Icon(Icons.alternate_email)),
              items: _accounts.map((a) => DropdownMenuItem(value: a['id']?.toString(), child: Text(a['email']?.toString() ?? 'Mailbox', overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (value) async {
                setState(() {
                  _accountId = value;
                  _folders = [];
                  _messages = [];
                  _selectedMessage = null;
                });
                await _loadFolders();
              },
            ),
            const SizedBox(height: 18),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('FOLDERS', style: TextStyle(fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800, color: Color(0xFF806C61)))),
            const SizedBox(height: 8),
            Expanded(
              child: _folders.isEmpty
                  ? const Center(child: Text('Loading folders…', style: TextStyle(color: Color(0xFF806C61))))
                  : ListView(
                      children: _folders.map((f) {
                        final path = f['path']?.toString() ?? '';
                        final selected = path == _folder;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: ListTile(
                            dense: true,
                            selected: selected,
                            selectedTileColor: const Color(0xFFF5D8C2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            leading: Icon(_folderIcon(f), size: 19, color: selected ? _orange : _ink),
                            title: Text(f['name']?.toString() ?? path, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                            onTap: () async {
                              setState(() {
                                _folder = path;
                                _selectedMessage = null;
                              });
                              await _loadMessages();
                            },
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const Divider(color: _line),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Add mailbox'),
              onTap: _showAddAccount,
            ),
            if (account != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFF8D2929)),
                title: const Text('Remove mailbox'),
                onTap: () => _removeAccount(account),
              ),
          ],
        ),
      );

  IconData _folderIcon(Map<String, dynamic> folder) {
    switch (folder['specialUse']) {
      case '\\Inbox': return Icons.inbox_outlined;
      case '\\Sent': return Icons.send_outlined;
      case '\\Drafts': return Icons.drafts_outlined;
      case '\\Trash': return Icons.delete_outline;
      case '\\Junk': return Icons.report_gmailerrorred_outlined;
      case '\\Archive': return Icons.archive_outlined;
      default: return Icons.folder_outlined;
    }
  }

  Widget _mobileMailboxSelector(Map<String, dynamic>? account) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _accountId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Mailbox', prefixIcon: Icon(Icons.alternate_email)),
                items: _accounts.map((a) => DropdownMenuItem(value: a['id']?.toString(), child: Text(a['email']?.toString() ?? 'Mailbox', overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (value) async {
                  setState(() {
                    _accountId = value;
                    _folders = [];
                    _messages = [];
                  });
                  await _loadFolders();
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(tooltip: 'Folders', onPressed: _showFolders, icon: const Icon(Icons.folder_open_outlined)),
            IconButton(tooltip: 'Add mailbox', onPressed: _showAddAccount, icon: const Icon(Icons.add_circle_outline)),
          ],
        ),
      );

  Widget _messageList() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_folder, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.7)),
                  Text('${_messages.length} recent messages', style: const TextStyle(color: Color(0xFF806C61))),
                ])),
                IconButton(tooltip: 'Refresh', onPressed: _loadingMessages ? null : _loadMessages, icon: const Icon(Icons.refresh_rounded)),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          Expanded(
            child: _loadingMessages
                ? const Center(child: CircularProgressIndicator(color: _orange))
                : _messages.isEmpty
                    ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.mark_email_read_outlined, size: 54, color: Color(0xFFD5BDA8)), SizedBox(height: 12), Text('Nothing here yet', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: _ink)), SizedBox(height: 4), Text('Pull to refresh or choose another folder.', style: TextStyle(color: Color(0xFF806C61)))]))
                    : RefreshIndicator(
                        color: _orange,
                        onRefresh: _loadMessages,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _messages.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 78, color: _line),
                          itemBuilder: (context, index) {
                            final m = _messages[index];
                            final from = (m['from'] as List? ?? const []).cast<Map>().firstOrNull;
                            final sender = from?['name']?.toString().trim().isNotEmpty == true ? from!['name'].toString() : from?['address']?.toString() ?? 'Unknown sender';
                            DateTime? date;
                            try { date = DateTime.parse(m['date'].toString()).toLocal(); } catch (_) {}
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                              leading: CircleAvatar(backgroundColor: const Color(0xFFF5D8C2), foregroundColor: _ink, child: Text(sender.isEmpty ? '?' : sender.characters.first.toUpperCase())),
                              title: Text(sender, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: m['seen'] == true ? FontWeight.w500 : FontWeight.w800)),
                              subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(m['subject']?.toString() ?? '(no subject)', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: m['seen'] == true ? FontWeight.w400 : FontWeight.w700, color: _ink)),
                                if ((m['snippet']?.toString() ?? '').isNotEmpty) Text(m['snippet'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF806C61))),
                              ])),
                              trailing: date == null ? null : Text(DateFormat(date.year == DateTime.now().year ? 'MMM d' : 'yMMMd').format(date), style: const TextStyle(fontSize: 11, color: Color(0xFF806C61))),
                              onTap: () => _openMessage(m),
                            );
                          },
                        ),
                      ),
          ),
        ],
      );

  Widget _messageReader(Map<String, dynamic> message) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
            child: Row(children: [
              IconButton(tooltip: 'Back to messages', onPressed: () => setState(() => _selectedMessage = null), icon: const Icon(Icons.arrow_back_rounded)),
              const SizedBox(width: 4),
              const Expanded(child: Text('Message', style: TextStyle(fontWeight: FontWeight.w700))),
              IconButton(tooltip: 'Refresh', onPressed: _loadMessages, icon: const Icon(Icons.refresh_rounded)),
            ]),
          ),
          const Divider(height: 1, color: _line),
          Expanded(
            child: _busy
                ? const Center(child: CircularProgressIndicator(color: _orange))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(message['subject']?.toString() ?? '(no subject)', style: const TextStyle(fontSize: 28, height: 1.2, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.7)),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFFFFEFE0), borderRadius: BorderRadius.circular(18)),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const CircleAvatar(backgroundColor: Color(0xFFF5D8C2), child: Icon(Icons.person_outline, color: _ink)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(message['from']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
                                const SizedBox(height: 4),
                                Text('To: ${message['to'] ?? ''}', style: const TextStyle(fontSize: 12, color: Color(0xFF806C61))),
                                if (message['date'] != null) Text(_formatDate(message['date']), style: const TextStyle(fontSize: 12, color: Color(0xFF806C61))),
                              ])),
                            ]),
                          ),
                          const SizedBox(height: 24),
                          SelectableText(
                            (message['text']?.toString().trim().isNotEmpty == true)
                                ? message['text'].toString()
                                : 'This message has no plain-text body. HTML-only content is intentionally not rendered until a safe HTML sanitizer is integrated.',
                            style: const TextStyle(fontSize: 15, height: 1.7, color: _ink),
                          ),
                          const SizedBox(height: 30),
                          OutlinedButton.icon(
                            onPressed: () => _showCompose(
                              to: _replyAddress(message['from']?.toString() ?? ''),
                              subject: _replySubject(message['subject']?.toString() ?? ''),
                            ),
                            icon: const Icon(Icons.reply_outlined),
                            label: const Text('Reply'),
                          ),
                        ]),
                      ),
                    ),
                  ),
          ),
        ],
      );

  String _formatDate(dynamic raw) {
    try { return DateFormat('EEE, MMM d · h:mm a').format(DateTime.parse(raw.toString()).toLocal()); } catch (_) { return ''; }
  }

  String _replyAddress(String from) {
    final match = RegExp(r'<([^<>]+@[^<>]+)>').firstMatch(from);
    if (match != null) return match.group(1)!;
    final email = RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false).firstMatch(from);
    return email?.group(0) ?? '';
  }

  String _replySubject(String subject) => subject.toLowerCase().startsWith('re:') ? subject : 'Re: $subject';

  void _showFolders() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Folders', style: TextStyle(fontWeight: FontWeight.w800))),
            ..._folders.map((f) => ListTile(
              leading: Icon(_folderIcon(f)),
              title: Text(f['name']?.toString() ?? f['path']?.toString() ?? ''),
              selected: f['path'] == _folder,
              onTap: () async {
                setState(() {
                  _folder = f['path']?.toString() ?? 'INBOX';
                  _selectedMessage = null;
                });
                Navigator.pop(context);
                await _loadMessages();
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showAddAccount() {
    final email = TextEditingController();
    final password = TextEditingController();
    final imap = TextEditingController(text: 'imap.gmail.com');
    final smtp = TextEditingController(text: 'smtp.gmail.com');
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Connect a mailbox'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Use the app password from your mail provider, not your normal account password. This initial version supports IMAP 993 and SMTP 465 over implicit TLS.', style: TextStyle(height: 1.45, color: Color(0xFF806C61))),
                const SizedBox(height: 16),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.alternate_email))),
                const SizedBox(height: 10),
                TextField(controller: password, obscureText: true, autofillHints: const [AutofillHints.password], decoration: const InputDecoration(labelText: 'Provider app password', prefixIcon: Icon(Icons.key_outlined))),
                const SizedBox(height: 10),
                TextField(controller: imap, decoration: const InputDecoration(labelText: 'IMAP host')),
                const SizedBox(height: 10),
                TextField(controller: smtp, decoration: const InputDecoration(labelText: 'SMTP host')),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: _busy ? null : () async {
                if (email.text.trim().isEmpty || password.text.isEmpty || imap.text.trim().isEmpty || smtp.text.trim().isEmpty) {
                  setDialogState(() {});
                  return;
                }
                Navigator.pop(context);
                await _connectAccount(email: email.text, password: password.text, imapHost: imap.text, smtpHost: smtp.text);
                email.dispose();
                password.dispose();
                imap.dispose();
                smtp.dispose();
              },
              child: Text(_busy ? 'Connecting…' : 'Connect'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompose({String to = '', String subject = ''}) {
    final toController = TextEditingController(text: to);
    final subjectController = TextEditingController(text: subject);
    final bodyController = TextEditingController();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('New message'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: toController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'To', hintText: 'person@example.com')),
              const SizedBox(height: 10),
              TextField(controller: subjectController, decoration: const InputDecoration(labelText: 'Subject')),
              const SizedBox(height: 10),
              TextField(controller: bodyController, minLines: 8, maxLines: 16, decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: _busy ? null : () {
              final recipients = toController.text.trim();
              if (recipients.isEmpty || !recipients.contains('@')) {
                setState(() => _error = 'Enter at least one valid recipient address.');
                return;
              }
              Navigator.pop(context);
              _sendMessage(recipients, subjectController.text, bodyController.text);
              toController.dispose();
              subjectController.dispose();
              bodyController.dispose();
            },
            icon: const Icon(Icons.send_outlined),
            label: Text(_busy ? 'Sending…' : 'Send'),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFFE0DD), borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, color: Color(0xFF8D2929)),
          const SizedBox(width: 10),
          Expanded(child: SelectableText(message, style: const TextStyle(color: Color(0xFF8D2929), height: 1.4))),
          IconButton(tooltip: 'Dismiss', onPressed: () => setState(() => _error = null), icon: const Icon(Icons.close, size: 18, color: Color(0xFF8D2929))),
        ]),
      );
}
