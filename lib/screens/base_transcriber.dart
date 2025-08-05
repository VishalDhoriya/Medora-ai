abstract class BaseTranscriber {
  Future<void> init();
  Future<void> start({bool demoMode = false});
  Future<String> stop();
}
