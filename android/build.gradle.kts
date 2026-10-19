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
// rive_common 0.3.x 的 compileSdk 较低，会把 AAR metadata 检查拖挂；
// 统一抬到 36（与 app 一致），否则 Rive 依赖无法参与构建。
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android is com.android.build.gradle.BaseExtension) {
            android.compileSdkVersion(36)
            android.defaultConfig.minSdk = 24
            // flutter_live2d 固定写死 CMake 3.10.2，而本机 Android SDK 只有
            // 3.22.1；把插件未安装的版本号拉回本机已安装版本，避免构建失败。
            if (project.name == "flutter_live2d") {
                android.externalNativeBuild.cmake.version = "3.22.1"
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
