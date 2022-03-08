// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cbl/cbl.dart';
import 'package:cbl_flutter/cbl_flutter.dart';
import 'package:cbl_flutter_ce/cbl_flutter_ce.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class ModelA {
  static const String typeIdentifier = 'modelA';

  String? id;
  String? name;
  String? address;
  String type = typeIdentifier;

  ModelA();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'type': type,
      };

  factory ModelA.fromJson(Map<String, dynamic> json) => ModelA()
    ..id = json['id']
    ..name = json['name']
    ..address = json['address']
    ..type = json['type'];
}

class ModelB {
  static const String typeIdentifier = 'modelB';

  String? id;
  int? counter;
  String? name;
  String type = typeIdentifier;

  ModelB();

  Map<String, dynamic> toJson() => {
        'id': id,
        'counter': counter,
        'name': name,
        'type': type,
      };

  factory ModelB.fromJson(Map<String, dynamic> json) => ModelB()
    ..id = json['id']
    ..counter = json['counter']
    ..name = json['name']
    ..type = json['type'];
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const String _dbName = 'test_database';

  late Database _db;

  late StreamSubscription _modelASub;
  late StreamSubscription _modelBSub;

  List<ModelA> _aInstances = [];
  List<ModelB> _bInstances = [];

  @override
  void initState() {
    super.initState();

    _openDatabase();
  }

  @override
  void dispose() {
    super.dispose();
    _db.close();
    _modelASub.cancel();
    _modelBSub.cancel();
  }

  void _openDatabase() async {
    if (Platform.isIOS || Platform.isAndroid) {
      CblFlutterCe.registerWith();
    }
    await CouchbaseLiteFlutter.init();

    Database.log
      ..console.level = LogLevel.debug
      ..custom = DartConsoleLogger(LogLevel.debug);

    _db = await Database.openAsync(_dbName);

    Query modelAQuery = const QueryBuilder()
        .select(SelectResult.all(), SelectResult.expression(Meta.id))
        .from(DataSource.database(_db))
        .where(Expression.property('type').equalTo(Expression.string(ModelA.typeIdentifier)));
    Query modelBQuery = const QueryBuilder()
        .select(SelectResult.all(), SelectResult.expression(Meta.id))
        .from(DataSource.database(_db))
        .where(Expression.property('type').equalTo(Expression.string(ModelB.typeIdentifier)));

    _modelASub = modelAQuery
        .changes()
        .map((change) => change.results.asStream().map((result) {
              Map<String, Object?> plainMap = result.toPlainMap();
              ModelA aInstance = ModelA.fromJson(plainMap[_dbName] as Map<String, Object?>);
              aInstance.id = plainMap['id'] as String;
              return aInstance;
            }).toList())
        .listen((aInstancesFuture) async {
      List<ModelA> aInstances = await aInstancesFuture;

      if (mounted) {
        setState(() {
          _aInstances = aInstances;
        });
      }
    });
    _modelBSub = modelBQuery
        .changes()
        .map((change) => change.results.asStream().map((result) {
              Map<String, Object?> plainMap = result.toPlainMap();
              ModelB bInstance = ModelB.fromJson(plainMap[_dbName] as Map<String, Object?>);
              bInstance.id = plainMap['id'] as String;
              return bInstance;
            }).toList())
        .listen((bInstancesFuture) async {
      List<ModelB> bInstances = await bInstancesFuture;

      if (mounted) {
        setState(() {
          _bInstances = bInstances;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test'),
      ),
      body: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () {
                    String address = (['Address 1', 'Address 2', 'Address 3']..shuffle()).first;
                    String name = (['Name 1', 'Name 2', 'Name 3']..shuffle()).first;
                    ModelA instance = ModelA()
                      ..address = address
                      ..name = name;

                    MutableDocument doc = MutableDocument(instance.toJson());
                    _db.saveDocument(doc);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Model A instance'),
                ),
                Expanded(
                  child: ListView.builder(
                    itemBuilder: (context, index) => ListTile(
                      title: Text('Model A ${_aInstances[index].name!}'),
                      subtitle: Text(_aInstances[index].address!),
                    ),
                    itemCount: _aInstances.length,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () {
                    String name = (['Name 1', 'Name 2', 'Name 3']..shuffle()).first;
                    int counter = Random().nextInt(100);
                    ModelB instance = ModelB()
                      ..counter = counter
                      ..name = name;

                    MutableDocument doc = MutableDocument(instance.toJson());
                    _db.saveDocument(doc);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Model B instance'),
                ),
                Expanded(
                  child: ListView.builder(
                    itemBuilder: (context, index) => ListTile(
                      title: Text('Model B ${_bInstances[index].name!}'),
                      subtitle: Text(_bInstances[index].counter!.toString()),
                    ),
                    itemCount: _bInstances.length,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
