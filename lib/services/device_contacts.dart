import 'dart:io';

import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_contacts/flutter_contacts.dart' as device;

import '../models/contact.dart';
import 'contacts.dart';
import 'platform_caps.dart';

/// What an import did, in the words the screen can say it in.
class ContactImport {
  const ContactImport({
    this.imported = 0,
    this.found = 0,
    this.refused = false,
    this.error,
  });

  /// How many addresses were new or changed in Ace Mail's own list.
  final int imported;

  /// How many addresses the device's book offered, before de-duplication.
  final int found;

  /// True when permission was refused. Distinct from an error: nothing is
  /// broken, somebody said no, and the way forward is the system settings
  /// rather than a retry.
  final bool refused;

  /// Something went wrong that was nobody's decision.
  final String? error;

  bool get ok => error == null && !refused;
}

/// The device's address book, read once and only when asked.
///
/// Ace Mail builds its contact list out of mail, which is why the tab is useful
/// on the first launch. The address book is the other half — the people you have
/// written to from other apps, saved on the phone — and it is the one thing here
/// that needs a permission, so it is behind a button rather than run at startup.
///
/// The permission is asked for at the moment of the tap, and the reason is
/// visible on the screen when it is asked. A prompt that appears during sign-in,
/// with no context and no way to know what it is for, is the prompt people learn
/// to refuse.
abstract final class DeviceContacts {
  /// Whether this platform has an address book this can read.
  ///
  /// False on Linux and Windows, where the plugin has no implementation. The
  /// row is hidden there rather than offering a button that can only fail.
  static bool get isSupported =>
      PlatformCaps.isAndroid || PlatformCaps.isIOS || Platform.isMacOS;

  /// Asks for permission, reads the book, and imports every address it finds.
  static Future<ContactImport> import() async {
    try {
      final device.PermissionStatus status =
          await device.FlutterContacts.permissions.request(
        device.PermissionType.read,
      );

      switch (status) {
        case device.PermissionStatus.granted:
        case device.PermissionStatus.limited:
          break;
        case device.PermissionStatus.denied:
        case device.PermissionStatus.notDetermined:
          return const ContactImport(
            refused: true,
            error: 'Ace Mail was not given access to your contacts.',
          );
        case device.PermissionStatus.permanentlyDenied:
        case device.PermissionStatus.restricted:
          return const ContactImport(
            refused: true,
            error: 'Contacts access is switched off for Ace Mail. It can be '
                'turned on in the system settings.',
          );
      }

      final List<device.Contact> found = await device.FlutterContacts.getAll(
        properties: <device.ContactProperty>{
          device.ContactProperty.name,
          device.ContactProperty.email,
        },
      );

      final List<Contact> addresses = <Contact>[];
      int offered = 0;
      for (final device.Contact person in found) {
        final String name = (person.displayName ?? '').trim();
        for (final device.Email email in person.emails) {
          final String address = email.address.trim().toLowerCase();
          if (!address.contains('@')) continue;
          offered++;
          addresses.add(Contact(email: address, name: name, saved: true));
        }
      }

      final int changed = await Contacts.importContacts(addresses);
      return ContactImport(imported: changed, found: offered);
    } on PlatformException catch (error) {
      return ContactImport(
        error: error.message ?? 'The address book could not be read.',
      );
    } on MissingPluginException {
      // No implementation on this platform, whatever isSupported said.
      return const ContactImport(
        error: 'This device has no address book Ace Mail can read.',
      );
    } catch (error) {
      return ContactImport(error: 'The address book could not be read: $error');
    }
  }

  /// Opens the system settings page for this app, for the case where the
  /// permission was refused for good and only the person can undo it.
  static Future<void> openSettings() async {
    try {
      await device.FlutterContacts.permissions.openSettings();
    } catch (_) {
      // Nothing to open. The screen still says where the setting is.
    }
  }
}
