import 'dart:convert';
import 'dart:typed_data';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:localstorage/localstorage.dart';
import 'dart:async';
import 'dart:core';
import 'package:path/path.dart' as p;
import 'package:moor/moor.dart';
import 'package:moor/moor_web.dart';

Future<Database> getDatabase(Client client, Store store) async {
  final db = Database(WebDatabase.withStorage(MoorWebStorage.indexedDbIfSupported('foxies'), logStatements: true));
  return db;
}

class Store {
  final LocalStorage storage;
  final FlutterSecureStorage secureStorage;

  Store() :
    storage = LocalStorage('LocalStorage'),
    secureStorage = kIsWeb ? null : FlutterSecureStorage();

  Future<dynamic> getItem(String key) async {
    if (kIsWeb) {
      await storage.ready;
      try {
        return await storage.getItem(key);
      } catch (_) {
        return null;
      }
    }
    try {
      return await secureStorage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> setItem(String key, String value) async {
    if (kIsWeb) {
      await storage.ready;
      return await storage.setItem(key, value);
    }
    if (value == null) {
      return await secureStorage.delete(key: key);
    } else {
      return await secureStorage.write(key: key, value: value);
    }
  }
}

/*
class Store extends StoreAPI {
  final Client client;
  final LocalStorage storage;
  final FlutterSecureStorage secureStorage;

  Store(this.client)
      : storage = LocalStorage('LocalStorage'),
        secureStorage = kIsWeb ? null : FlutterSecureStorage() {
    _init();
  }

  Future<dynamic> getItem(String key) async {
    if (kIsWeb) {
      await storage.ready;
      try {
        return await storage.getItem(key);
      } catch (_) {
        return null;
      }
    }
    try {
      return await secureStorage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> setItem(String key, String value) async {
    if (kIsWeb) {
      await storage.ready;
      return await storage.setItem(key, value);
    }
    if (value == null) {
      return await secureStorage.delete(key: key);
    } else {
      return await secureStorage.write(key: key, value: value);
    }
  }

  Future<Map<String, DeviceKeysList>> getUserDeviceKeys() async {
    final deviceKeysListString = await getItem(_UserDeviceKeysKey);
    if (deviceKeysListString == null) return {};
    Map<String, dynamic> rawUserDeviceKeys = json.decode(deviceKeysListString);
    Map<String, DeviceKeysList> userDeviceKeys = {};
    for (final entry in rawUserDeviceKeys.entries) {
      userDeviceKeys[entry.key] = DeviceKeysList.fromJson(entry.value);
    }
    return userDeviceKeys;
  }

  Future<void> storeUserDeviceKeys(
      Map<String, DeviceKeysList> userDeviceKeys) async {
    await setItem(_UserDeviceKeysKey, json.encode(userDeviceKeys));
  }

  String get _UserDeviceKeysKey => "${client.clientName}.user_device_keys";

  _init() async {
    final credentialsStr = await getItem(client.clientName);

    if (credentialsStr == null || credentialsStr.isEmpty) {
      client.onLoginStateChanged.add(LoginState.loggedOut);
      return;
    }
    debugPrint("[Matrix] Restoring account credentials");
    final Map<String, dynamic> credentials = json.decode(credentialsStr);
    if (credentials["homeserver"] == null ||
        credentials["token"] == null ||
        credentials["userID"] == null) {
      client.onLoginStateChanged.add(LoginState.loggedOut);
      return;
    }
    client.connect(
      newDeviceID: credentials["deviceID"],
      newDeviceName: credentials["deviceName"],
      newHomeserver: credentials["homeserver"],
      newMatrixVersions: List<String>.from(credentials["matrixVersions"] ?? []),
      newToken: credentials["token"],
      newUserID: credentials["userID"],
      newPrevBatch: kIsWeb
          ? null
          : (credentials["prev_batch"]?.isEmpty ?? true)
              ? null
              : credentials["prev_batch"],
      newOlmAccount: credentials["olmAccount"],
    );
  }

  Future<void> storeClient() async {
    final Map<String, dynamic> credentials = {
      "deviceID": client.deviceID,
      "deviceName": client.deviceName,
      "homeserver": client.homeserver,
      "matrixVersions": client.matrixVersions,
      "token": client.accessToken,
      "userID": client.userID,
      "olmAccount": client.pickledOlmAccount,
    };
    await setItem(client.clientName, json.encode(credentials));
    return;
  }

  Future<void> clear() => kIsWeb ? storage.clear() : secureStorage.deleteAll();
}

/// Responsible to store all data persistent and to query objects from the
/// database.
class ExtendedStore extends Store implements ExtendedStoreAPI {
  /// The maximum time that files are allowed to stay in the
  /// store. By default this is are 30 days.
  static const int MAX_FILE_STORING_TIME = 1 * 30 * 24 * 60 * 60 * 1000;

  @override
  final bool extended = true;

  ExtendedStore(Client client) : super(client);

  sqlite.Database _db;
  var txn;

  /// SQLite database for all persistent data. It is recommended to extend this
  /// SDK instead of writing direct queries to the database.
  //Database get db => _db;

  @override
  _init() async {
    // Open the database and migrate if necessary.
    var databasePath = await sqlite.getDatabasesPath();
    String path = p.join(databasePath, "FluffyMatrix.db");
    _db = await sqlite.openDatabase(path, version: 20,
        onCreate: (sqlite.Database db, int version) async {
      await createTables(db);
    }, onUpgrade: (sqlite.Database db, int oldVersion, int newVersion) async {
      debugPrint(
          "[Store] Migrate database from version $oldVersion to $newVersion");
      if (oldVersion >= 18 && newVersion <= 20) {
        await createTables(db);
      } else if (oldVersion != newVersion) {
        // Look for an old entry in an old clients library
        List<Map> list = [];
        try {
          list = await db.rawQuery(
              "SELECT * FROM Clients WHERE client=?", [client.clientName]);
        } catch (_) {
          list = [];
        }
        client.prevBatch = null;
        await this.storePrevBatch(null);
        schemes.forEach((String name, String scheme) async {
          await db.execute("DROP TABLE IF EXISTS $name");
        });
        await createTables(db);

        if (list.length == 1) {
          debugPrint("[Store] Found old client from deprecated store");
          var clientList = list[0];
          _db = db;
          client.connect(
            newToken: clientList["token"],
            newHomeserver: clientList["homeserver"],
            newUserID: clientList["matrix_id"],
            newDeviceID: clientList["device_id"],
            newDeviceName: clientList["device_name"],
            newMatrixVersions:
                clientList["matrix_versions"].toString().split(","),
            newPrevBatch: null,
          );
          await db.execute("DROP TABLE IF EXISTS Clients");
          debugPrint(
              "[Store] Restore client credentials from deprecated database of ${client.userID}");
        }
      } else {
        client.onLoginStateChanged.add(LoginState.loggedOut);
      }
      return;
    });

    // Mark all pending events as failed.
    await _db.rawUpdate("UPDATE Events SET status=-1 WHERE status=0");

    // Delete all stored files which are older than [MAX_FILE_STORING_TIME]
    final int currentDeadline = DateTime.now().millisecondsSinceEpoch -
        ExtendedStore.MAX_FILE_STORING_TIME;
    await _db.rawDelete(
      "DELETE From Files WHERE saved_at<?",
      [currentDeadline],
    );

    super._init();
  }

  Future<void> setRoomPrevBatch(String roomId, String prevBatch) async {
    throw("bad: called setRoomPrevBatch");
  }

  Future<void> createTables(sqlite.Database db) async {
    schemes.forEach((String name, String scheme) async {
      await db.execute(scheme);
    });
  }

  /// Clears all tables from the database.
  Future<void> clear() async {
    schemes.forEach((String name, String scheme) async {
      await _db.rawDelete("DELETE FROM $name");
    });
    await super.clear();
    return;
  }

  Future<void> transaction(Function queries) async {
    throw("bad: called transaction");
  }

  /// Will be automatically called on every synchronisation.
  Future<void> storePrevBatch(String prevBatch) async {
    throw("bad: called storePrevBatch");
  }

  Future<void> storeRoomPrevBatch(Room room) async {
    throw("bad: called storeRoomPrevBatch");
  }

  /// Stores a RoomUpdate object in the database. Must be called inside of
  /// [transaction].
  Future<void> storeRoomUpdate(RoomUpdate roomUpdate) {
    throw("bad: called storeRoomUpdate");
  }

  /// Stores an UserUpdate object in the database. Must be called inside of
  /// [transaction].
  Future<void> storeUserEventUpdate(UserUpdate userUpdate) {
    throw("bad: called storeUserEventUpate");
  }

  Future<dynamic> redactMessage(EventUpdate eventUpdate) async {
    throw("bad: called redactMessage");
  }

  /// Stores an EventUpdate object in the database. Must be called inside of
  /// [transaction].
  Future<void> storeEventUpdate(EventUpdate eventUpdate) {
    throw("Bad: called storeEventUpdate");
  }

  /// Returns a User object by a given Matrix ID and a Room.
  Future<User> getUser({String matrixID, Room room}) async {
    throw("Bad: called getUser");
  }

  /// Returns a list of events for the given room and sets all participants.
  Future<List<Event>> getEventList(Room room) async {
    throw("Bad: called getEventList");
  }

  /// Returns all rooms, the client is participating. Excludes left rooms.
  Future<List<Room>> getRoomList({bool onlyLeft = false}) async {
    throw("Bad: called getRoomList");
  }

  Future<List<Map<String, dynamic>>> getStatesFromRoomId(String id) async {
    throw("Bad: called getStatesFromRoomId");
  }

  Future<List<Map<String, dynamic>>> getAccountDataFromRoomId(String id) async {
    throw("Bad: called getAccountDataFromRoomId");
  }

  Future<void> resetNotificationCount(String roomID) async {
    throw("Bad: called resetNotificationCount");
  }

  Future<void> forgetRoom(String roomID) async {
    throw("Bad: called forgetRoom");
  }

  /// Searches for the event in the store.
  Future<Event> getEventById(String eventID, Room room) async {
    throw("Bad: called getEventById");
  }

  Future<Map<String, AccountData>> getAccountData() async {
    throw("Bad: called getAccountData");
  }

  Future<Map<String, Presence>> getPresences() async {
    throw("Bad: called getPresences");
  }

  Future removeEvent(String eventId) async {
    throw("Bad: called removeEvent");
  }

  Future<void> storeFile(Uint8List bytes, String mxcUri) async {
    throw("Bad: called storeFile");
  }

  Future<Uint8List> getFile(String mxcUri) async {
    throw("Bad: called getFile");
  }

  static final Map<String, String> schemes = {
    /// The database scheme for the Room class.
    'Rooms': 'CREATE TABLE IF NOT EXISTS Rooms(' +
        'room_id TEXT PRIMARY KEY, ' +
        'membership TEXT, ' +
        'highlight_count INTEGER, ' +
        'notification_count INTEGER, ' +
        'prev_batch TEXT, ' +
        'joined_member_count INTEGER, ' +
        'invited_member_count INTEGER, ' +
        'heroes TEXT, ' +
        'UNIQUE(room_id))',

    /// The database scheme for the TimelineEvent class.
    'Events': 'CREATE TABLE IF NOT EXISTS Events(' +
        'event_id TEXT PRIMARY KEY, ' +
        'room_id TEXT, ' +
        'origin_server_ts INTEGER, ' +
        'sender TEXT, ' +
        'type TEXT, ' +
        'unsigned TEXT, ' +
        'content TEXT, ' +
        'prev_content TEXT, ' +
        'state_key TEXT, ' +
        "status INTEGER, " +
        'UNIQUE(event_id))',

    /// The database scheme for room states.
    'RoomStates': 'CREATE TABLE IF NOT EXISTS RoomStates(' +
        'event_id TEXT PRIMARY KEY, ' +
        'room_id TEXT, ' +
        'origin_server_ts INTEGER, ' +
        'sender TEXT, ' +
        'state_key TEXT, ' +
        'unsigned TEXT, ' +
        'prev_content TEXT, ' +
        'type TEXT, ' +
        'content TEXT, ' +
        'UNIQUE(room_id,state_key,type))',

    /// The database scheme for room states.
    'AccountData': 'CREATE TABLE IF NOT EXISTS AccountData(' +
        'type TEXT PRIMARY KEY, ' +
        'content TEXT, ' +
        'UNIQUE(type))',

    /// The database scheme for room states.
    'RoomAccountData': 'CREATE TABLE IF NOT EXISTS RoomAccountData(' +
        'type TEXT, ' +
        'room_id TEXT, ' +
        'content TEXT, ' +
        'UNIQUE(type,room_id))',

    /// The database scheme for room states.
    'Presences': 'CREATE TABLE IF NOT EXISTS Presences(' +
        'type TEXT PRIMARY KEY, ' +
        'sender TEXT, ' +
        'content TEXT, ' +
        'UNIQUE(sender))',

    /// The database scheme for room states.
    'Files': 'CREATE TABLE IF NOT EXISTS Files(' +
        'mxc_uri TEXT PRIMARY KEY, ' +
        'bytes BLOB, ' +
        'saved_at INTEGER, ' +
        'UNIQUE(mxc_uri))',
  };

  @override
  int get maxFileSize => 1 * 1024 * 1024;
}
*/
