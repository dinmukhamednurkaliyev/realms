import 'package:flutter/widgets.dart';
import 'package:realms/app/app.dart';

/// Initializes Flutter before composing the application.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RealmsApp());
}
