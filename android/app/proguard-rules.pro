# ProDFOS release shrinking rules (R8).
#
# Scanner fix: since Android Gradle Plugin 9, R8 runs in strict full mode. A
# plain "-keep class X" no longer keeps X's no-argument constructor. Google
# ML Kit starts itself by creating its "component registrars" by name
# (reflection) with exactly that constructor. With the constructor removed,
# ML Kit silently starts with nothing registered, and opening the document
# scanner crashed with:
#   PlatformException(error, null, null, java.lang.NullPointerException
#     at java.util.Objects.requireNonNull ...)
# These rules keep the registrars together with their constructors.
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }
-keep class com.google.mlkit.common.internal.CommonComponentRegistrar { <init>(); }
-keep class com.google.mlkit.common.internal.MlKitComponentDiscoveryService { <init>(); }
-keep class com.google.mlkit.common.internal.MlKitInitProvider { <init>(); }

# The document scanner plugin and the ML Kit classes it talks to.
-keep class com.google_mlkit_document_scanner.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google.mlkit.vision.documentscanner.** { *; }
