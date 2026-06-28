// Conditional export: web-safe stub vs native TFLite implementation.
// dart.library.io is available on Android/iOS/Linux/macOS/Windows but NOT on web.
export 'model_service_stub.dart'
  if (dart.library.io) 'model_service_io.dart';
