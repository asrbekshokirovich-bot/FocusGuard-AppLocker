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

// THE BRUTE FORCE FIX
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as? com.android.build.gradle.BaseExtension
            android?.compileSdkVersion(34)
            android?.targetSdkVersion(34)
            
            if (android?.namespace == null) {
                android?.namespace = if (project.name == "device_apps") "fr.g123k.deviceapps" else "com.example." + project.name.replace(":", ".")
            }
        }
    }
    
    project.configurations.all {
        resolutionStrategy {
            force("androidx.core:core:1.10.1")
            force("androidx.core:core-ktx:1.10.1")
            force("androidx.annotation:annotation:1.6.0")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
