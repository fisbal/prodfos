allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Older plugins (e.g. syncfusion_flutter_pdfviewer 27) pin compileSdk 31, which
// AGP 9 now rejects for their dependencies. Raise any plugin below 36 to 36.
// Registered before evaluationDependsOn(":app") so afterEvaluate is still allowed.
subprojects {
    if (name != "app") {
        afterEvaluate {
            val android = extensions.findByName("android")
            if (android is com.android.build.gradle.BaseExtension) {
                val current = android.compileSdkVersion?.removePrefix("android-")?.toIntOrNull() ?: 0
                if (current < 36) android.compileSdkVersion(36)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

// AGP 9's release "lintVital" check crashes inside third-party plugins
// (e.g. image_picker_android: "this is a bug in lint"). It only lints, so skip it.
allprojects {
    tasks.matching { it.name.startsWith("lintVital") }.configureEach { enabled = false }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
