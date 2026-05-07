import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'database/database.dart';
import 'database/seed_loader.dart';
import 'firebase_options.dart';
import 'services/purchases_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final db = AppDatabase();
  await SeedLoader(db).seedIfNeeded();

  final purchases = PurchasesService();
  await purchases.initialize();

  runApp(LoadOutApp(database: db, purchases: purchases));
}
