import 'package:flutter/material.dart';
import 'package:sea_scene/data/di/injection.dart';
import 'package:sea_scene/domain/audio/app_audio.dart';
import 'package:sea_scene/domain/style/colors.dart';
import 'package:sea_scene/domain/style/strings.dart';
import 'package:sea_scene/domain/style/text_styles.dart';
import 'package:sea_scene/presentation/screen/scene_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  runApp(const SeaSceneApp());
}

class SeaSceneApp extends StatelessWidget {
  const SeaSceneApp({super.key});

  @override
  Widget build(BuildContext context) {
    const colors = DefaultAppColors();
    const strings = DefaultAppStrings();

    return MaterialApp(
      title: strings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: colors.backdrop,
        // Colour, type, copy and sound all reach the tree the same way, so no
        // widget has to know where any of them came from.
        extensions: <ThemeExtension<dynamic>>[
          const AppColorsExtension(colors: colors),
          const AppTypographyExtension(typography: DefaultAppTypography()),
          const AppStringsExtension(strings: strings),
          AppAudioExtension(audio: locate<AppAudio>()),
        ],
      ),
      home: const SeaScene(),
    );
  }
}
