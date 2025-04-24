import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_swift_camera/firebase_options.dart';
import 'package:provider/provider.dart';
import 'view/about_login/start_screen.dart';
import 'view_model/auth_view_model.dart';
import 'view_model/category_view_model.dart';
import 'view_model/audio_view_model.dart';
import 'view_model/comment_view_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => CategoryViewModel()),
        ChangeNotifierProvider(create: (_) => AudioViewModel()),
        ChangeNotifierProvider(create: (_) => CommentAudioViewModel()),
      ],
      child: MaterialApp(home: StartScreen()),
    );
  }
}
