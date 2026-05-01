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

// Force all subprojects to use a modern compileSdk and namespace
subprojects {
    val p = this
    p.plugins.whenPluginAdded {
        val android = p.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        if (android != null) {
            // Force modern compileSdk to fix 'lStar' and other resource errors
            android.compileSdkVersion(34)
            
            // Set namespace if missing
            if (android.namespace == null) {
                android.namespace = if (p.name == "device_apps") "fr.g123k.deviceapps" else "com.example." + p.name.replace(":", ".")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
