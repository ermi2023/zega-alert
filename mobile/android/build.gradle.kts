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

subprojects {
    val subProject = this
    fun forceCompileSdk() {
        val androidExt = subProject.extensions.findByName("android") ?: return
        val methods = androidExt.javaClass.methods
        val setterNames = listOf("setCompileSdkVersion", "setCompileSdk")
        var applied = false
        for (name in setterNames) {
            val m = methods.firstOrNull { it.name == name && it.parameterTypes.size == 1 }
            if (m != null) {
                try {
                    m.invoke(androidExt, 36)
                    applied = true
                    break
                } catch (_: Throwable) {
                }
            }
        }
        if (!applied) {
            val m = methods.firstOrNull {
                it.name == "compileSdkVersion" && it.parameterTypes.size == 1
            }
            if (m != null) {
                try {
                    m.invoke(androidExt, 36)
                } catch (_: Throwable) {
                }
            }
        }
    }
    try {
        subProject.afterEvaluate { forceCompileSdk() }
    } catch (_: Throwable) {
        forceCompileSdk()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
