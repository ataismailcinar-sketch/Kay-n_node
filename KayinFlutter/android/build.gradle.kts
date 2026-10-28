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

// Eski eklentiler (ör. tflite_flutter) Java'yı 1.8 hedefiyle, Kotlin'i ise JDK sürümüyle
// derliyor; Gradle bu uyuşmazlığı reddediyor. Kotlin hedefini aynı modülün Java hedefine eşitle.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        val javaGorevi = project.tasks.findByName(name.replace("Kotlin", "JavaWithJavac")) as? JavaCompile
        if (javaGorevi != null) {
            compilerOptions.jvmTarget.set(
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(javaGorevi.targetCompatibility),
            )
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
