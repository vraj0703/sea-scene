import 'package:flutter/foundation.dart';

typedef DependencyFactory<T> = T Function();

class DependencyManager {
  DependencyManager._();
  static final DependencyManager _instance = DependencyManager._();
  static DependencyManager get instance => _instance;

  final Map<Type, dynamic> _singletons = {};
  final Map<Type, DependencyFactory<dynamic>> _factories = {};

  /// Registers a singleton instance of [T].
  void registerSingleton<T>(T instance) {
    if (_singletons.containsKey(T)) {
      throw Exception(
        'Dependency of type $T is already registered as singleton.',
      );
    }
    _singletons[T] = instance;
  }

  /// Registers a factory for [T]. A new instance will be created every time it's requested.
  void registerFactory<T>(DependencyFactory<T> factory) {
    if (_factories.containsKey(T)) {
      throw Exception(
        'Dependency of type $T is already registered as factory.',
      );
    }
    _factories[T] = factory;
  }

  /// Registers a lazy singleton for [T]. The instance is created only when requested for the first time.
  void registerLazySingleton<T>(DependencyFactory<T> factory) {
    registerFactory<T>(() {
      if (!_singletons.containsKey(T)) {
        _singletons[T] = factory();
      }
      return _singletons[T] as T;
    });
  }

  /// Retrieves the instance of [T].
  T get<T>() {
    if (_singletons.containsKey(T)) {
      return _singletons[T] as T;
    }
    if (_factories.containsKey(T)) {
      return _factories[T]!() as T;
    }
    throw Exception('Dependency of type $T is not registered.');
  }

  /// Clears every registration.
  ///
  /// The container is a process-wide singleton and registration throws on a
  /// duplicate, so without this a second call to `initDependencies()` fails.
  /// Tests need a clean container per case; production calls it never.
  @visibleForTesting
  void reset() {
    _singletons.clear();
    _factories.clear();
  }
}

/// Shortcut to get a dependency
T locate<T>() => DependencyManager.instance.get<T>();
