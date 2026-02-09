import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../core/utils.dart';

class ContactDiscovery {
  final Map<String, Contact> _contacts = {};
  final Map<String, String> _hashToContact = {}; 
  
  final StreamController<DiscoveryEvent> _eventController =
      StreamController<DiscoveryEvent>.broadcast();

  Stream<DiscoveryEvent> get eventStream => _eventController.stream;

  Future<void> addContact(Contact contact) async {
    _contacts[contact.id] = contact;

    final hash = _generateContactHash(contact);
    _hashToContact[hash] = contact.id;
    
    DebugUtils.log('Contact added: ${contact.name}', tag: 'CONTACTS');
  }

  Future<List<Contact>> discoverContacts(List<Contact> localContacts) async {
    final discovered = <Contact>[];
    
    try {
      
      final hashes = localContacts.map(_generateContactHash).toList();

      final payload = {
        'type': 'contact_discovery',
        'hashes': hashes,
      };

      DebugUtils.log(
        'Sent ${hashes.length} contact hashes for discovery',
        tag: 'CONTACTS',
      );

    } catch (e) {
      DebugUtils.logError('Contact discovery failed', error: e);
    }
    
    return discovered;
  }

  Future<void> processDiscoveryRequest(List<String> receivedHashes) async {
    final matches = <String>[];

    for (final hash in receivedHashes) {
      if (_hashToContact.containsKey(hash)) {
        matches.add(hash);
      }
    }
    
    if (matches.isNotEmpty) {
      DebugUtils.log('Found ${matches.length} mutual contacts', tag: 'CONTACTS');

      _eventController.add(DiscoveryEvent(
        type: DiscoveryEventType.mutualContactsFound,
        count: matches.length,
      ));
    }
  }

  String _generateContactHash(Contact contact) {
    
    final normalized = _normalizePhoneNumber(contact.phoneNumber ?? contact.id);

    const appSalt = 'speew_v1_contact_discovery';
    final salted = '$normalized:$appSalt';

    final bytes = utf8.encode(salted);
    final digest = sha256.convert(bytes);
    
    return digest.toString();
  }

  String _normalizePhoneNumber(String phone) {
    
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (digitsOnly.startsWith('0')) {
      return digitsOnly.substring(1);
    }
    
    return digitsOnly;
  }

  Future<List<Contact>> importSystemContacts() async {
    try {

      final imported = <Contact>[
        Contact(
          id: '1',
          name: 'João Silva',
          phoneNumber: '+5511999998888',
        ),
        Contact(
          id: '2',
          name: 'Maria Santos',
          phoneNumber: '+5511988887777',
        ),
      ];
      
      for (final contact in imported) {
        await addContact(contact);
      }
      
      DebugUtils.log('Imported ${imported.length} contacts', tag: 'CONTACTS');
      
      return imported;
    } catch (e) {
      DebugUtils.logError('Failed to import contacts', error: e);
      return [];
    }
  }

  void startPeriodicSync({Duration interval = const Duration(hours: 6)}) {
    Timer.periodic(interval, (_) async {
      final contacts = await importSystemContacts();
      await discoverContacts(contacts);
    });
    
    DebugUtils.log('Periodic contact sync started', tag: 'CONTACTS');
  }

  List<Contact> getContactsOnApp() {
    return _contacts.values.where((c) => c.isOnApp).toList();
  }

  Contact? findContact(String query) {
    query = query.toLowerCase();
    
    for (final contact in _contacts.values) {
      if (contact.name.toLowerCase().contains(query) ||
          (contact.phoneNumber?.contains(query) ?? false)) {
        return contact;
      }
    }
    
    return null;
  }

  List<Contact> getAllContacts() {
    return _contacts.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  void dispose() {
    _eventController.close();
  }
}

class Contact {
  final String id;
  final String name;
  final String? phoneNumber;
  final String? email;
  final String? photoUrl;
  bool isOnApp;
  DateTime? lastSeen;

  Contact({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.email,
    this.photoUrl,
    this.isOnApp = false,
    this.lastSeen,
  });

  String get displayName => name.isNotEmpty ? name : phoneNumber ?? id;
  
  String get initials {
    final parts = name.split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone_number': phoneNumber,
    'email': email,
    'photo_url': photoUrl,
    'is_on_app': isOnApp,
    'last_seen': lastSeen?.millisecondsSinceEpoch,
  };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    id: json['id'],
    name: json['name'],
    phoneNumber: json['phone_number'],
    email: json['email'],
    photoUrl: json['photo_url'],
    isOnApp: json['is_on_app'] ?? false,
    lastSeen: json['last_seen'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['last_seen'])
        : null,
  );
}

class DiscoveryEvent {
  final DiscoveryEventType type;
  final int? count;
  final Contact? contact;

  DiscoveryEvent({
    required this.type,
    this.count,
    this.contact,
  });
}

enum DiscoveryEventType {
  started,
  mutualContactsFound,
  contactJoinedApp,
  syncCompleted,
}

class QRContactSharing {
  
  static String generateQRData(Contact contact) {
    final data = {
      'type': 'speew_contact',
      'version': '1.0',
      'id': contact.id,
      'name': contact.name,
      'phone': contact.phoneNumber,
    };
    
    return jsonEncode(data);
  }

  static Contact? parseQRData(String qrData) {
    try {
      final data = jsonDecode(qrData) as Map<String, dynamic>;
      
      if (data['type'] != 'speew_contact') return null;
      
      return Contact(
        id: data['id'],
        name: data['name'],
        phoneNumber: data['phone'],
        isOnApp: true,
      );
    } catch (e) {
      return null;
    }
  }
}

class ContactGroup {
  final String id;
  final String name;
  final List<String> contactIds;
  final String? emoji;

  ContactGroup({
    required this.id,
    required this.name,
    required this.contactIds,
    this.emoji,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'contact_ids': contactIds,
    'emoji': emoji,
  };

  factory ContactGroup.fromJson(Map<String, dynamic> json) => ContactGroup(
    id: json['id'],
    name: json['name'],
    contactIds: List<String>.from(json['contact_ids']),
    emoji: json['emoji'],
  );
}