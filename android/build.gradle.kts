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

// THE ULTIMATE GLOBAL OVERRIDE
subprojects {
    // 1. Force modern compileSdk for EVERY plugin to fix lStar
    project.plugins.whenPluginAdded {
        val pluginName = this::class.java.simpleName
        if (pluginName.contains("AppPlugin") || pluginName.contains("LibraryPlugin")) {
            val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            android?.apply {
                compileSdkVersion(34)
                if (namespace == null) {
                    namespace = if (project.name == "device_apps") "fr.g123k.deviceapps" else "com.example." + project.name.replace(":", ".")
                }
            }
        }
    }

    // 2. Force a compatible version of core-ktx that works with url_launcher and fixes lStar (with compileSdk 34)
    project.configurations.all {
        resolutionStrategy {
            force("androidx.core:core:1.10.1")
            force("androidx.core:core-ktx:1.10.1")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
