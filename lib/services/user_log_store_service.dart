// ignore_for_file: avoid_print

import 'package:rider_ride_hailing_app/modal/users_log_modal.dart';
import 'package:sqflite/sqflite.dart';

class UserLogStoreService {
  late Database database;
  Future<void> initServices() async {
    print('initializing the database');
    database =
        await openDatabase('${await getDatabasesPath()}log_store_services.db',
            onCreate: (db, version) {
      print('create-----------------------------');
    }, onOpen: (db) {
      print('open-----------------------------');
    }, version: 1);
    if (database.isOpen == true) {}
    print('the database is ');
    try {
      database.execute(
          'CREATE TABLE  IF NOT EXISTS users_log(id INTEGER PRIMARY KEY,user_id TEXT,date TEXT,log_string TEXT )');
    } catch (e) {
      print(
          'error in creating table as it may already have been created IGNOREE $e');
    }
    print(database.isOpen);
  }

  Future<void> insertUserLog({
    required UsersLogModal usersLogModal,
  }) async {
    await initServices();
    Database db = database;
    Map<String, dynamic> json = {};
    json = usersLogModal.toJson();

    int result = await db.insert(
      'users_log',
      json,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('the insert users log is: $result');
  }

  Future<List<UsersLogModal>> getCurrrentUserLogs() async {
    await initServices();
    Database db = database;
    try {
      final List<Map<String, dynamic>> usersLogMap = await db.query(
        'users_log',
        where: 'user_id = ?',
        whereArgs: ["110011"],
      );
      return List.generate(usersLogMap.length, (i) {
        return UsersLogModal.fromJson(usersLogMap[i]);
      });
    } catch (er) {
      print('error---------------');
      throw ("error getting the response $er");
    }
  }

  Future<void> deleteTemplate(String userId) async {
    print('deleting template $userId');
    await initServices();
    Database db = database;
    await db.delete(
      'multiple_account_templates',
      where: 'userId= ?',
      whereArgs: [userId],
    );
    print('the template with template id $userId is deleted');
  }

  Future<void> deleteAllTemplate() async {
    print('deleting template ');
    await initServices();
    Database db = database;
    var result = await db.delete(
      'multiple_account_templates',
    );
    print('the template with template id is deleted $result');
  }
}
