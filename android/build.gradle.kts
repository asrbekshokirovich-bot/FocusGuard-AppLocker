allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Fixed namespace injection for remaining plugins
subprojects {
    val p = this
    p.plugins.whenPluginAdded {
        val android = p.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        if (android != null && android.namespace == null) {
            android.namespace = "com.example." + p.name.replace(":", ".")
        }
    }

    // Force compileSdk on every subproject AFTER its own gradle has run.
    // Legacy plugins (e.g. usage_stats) ship resources that reference
    // android:attr/lStar — present only on compileSdk 31+. Without this
    // override AAPT fails with "resource android:attr/lStar not found".
    p.afterEvaluate {
        val android = p.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        android?.compileSdkVersion(36)
    }

    project.configurations.all {
        resolutionStrategy {
            force("androidx.core:core:1.13.1")
            force("androidx.core:core-ktx:1.13.1")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
