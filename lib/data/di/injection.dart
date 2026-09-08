import 'package:sea_scene/data/audio/flame_app_audio.dart';
import 'package:sea_scene/data/di/dependency_manager.dart';
import 'package:sea_scene/data/shaders/shader_library.dart';
import 'package:sea_scene/domain/audio/app_audio.dart';
import 'package:sea_scene/presentation/bloc/scene_bloc.dart';

export 'package:sea_scene/data/di/dependency_manager.dart';

/// Wires the container. Called once, before the app is built.
Future<void> initDependencies() async {
  final di = DependencyManager.instance;

  // One shared audio backend: it owns a cache and a pool of players, so a
  // second instance would duplicate both and let cues talk over each other.
  di.registerLazySingleton<AppAudio>(FlameAppAudio.new);

  // One library for the whole app. Two very different things draw with these
  // — a Flame component and a widget — and compiling either twice would put
  // the same wait on the curtain twice.
  di.registerLazySingleton<ShaderLibrary>(ShaderLibrary.new);

  // A factory, so each provider gets an instance it exclusively owns and
  // closes.
  di.registerFactory<SceneBloc>(SceneBloc.new);
}
