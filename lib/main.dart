import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/notifications/notification_service.dart';
import 'core/routing/url_strategy.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    // Local reminder notifications (vaccinations, growth check-ins, care
    // log) are mobile-only for now — see docs/ARCHITECTURE.md.
    await NotificationService.instance.init();
  }
  runApp(const ProviderScope(child: MyBabyApp()));
}
