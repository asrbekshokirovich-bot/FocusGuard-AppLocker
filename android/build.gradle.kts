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

// THE ATOMIC FIX: Force all subprojects to use a safe version of androidx.core
subprojects {
    project.configurations.all {
        resolutionStrategy {
            force("androidx.core:core:1.6.0")
            force("androidx.core:core-ktx:1.6.0")
        }
    }
    
    // Also set namespace if missing
    val p = this
    p.plugins.whenPluginAdded {
        val android = p.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        if (android != null) {
            android.compileSdkVersion(34)
            if (android.namespace == null) {
                android.namespace = if (p.name == "device_apps") "fr.g123k.deviceapps" else "com.example." + p.name.replace(":", ".")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
