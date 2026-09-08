import 'package:sea_scene/presentation/bloc/scene_bloc.dart';

/// Abstraction over event dispatching to decouple game systems from the Bloc.
///
/// In production, [SceneBloc] implements this directly (`queue` → `add`).
/// This indirection allows game systems to dispatch events without holding
/// a reference to the full Bloc, enabling easier testing and potential
/// replacement of the state management layer.
abstract class Queuer {
  void queue({required SceneEvent event});
}
