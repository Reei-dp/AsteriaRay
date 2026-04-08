# path_provider_android resolves io.flutter.util.PathUtils via JNI (Class.forName).
# R8 release shrinking obfuscates or removes it unless kept — causes black screen at startup.
-keep class io.flutter.util.** { *; }
