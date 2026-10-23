import com.android.build.api.artifact.SingleArtifact
import javax.inject.Inject
import javax.xml.parsers.DocumentBuilderFactory

plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "io.github.danajerban.fuegoos"
    compileSdk = 34

    defaultConfig {
        applicationId = "io.github.danajerban.fuegoos"
        // The TV runs Android TV OS 14 (API 34), and nothing else is supported.
        minSdk = 34
        targetSdk = 34
        versionCode = 1
        versionName = "0.0.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.junit)
    androidTestImplementation(libs.uiautomator)
}

/**
 * Fails the build when the merged manifest breaks the Launcher's rules: no INTERNET permission,
 * no broadcast receivers, and no services other than [allowedServices].
 */
abstract class CheckLauncherManifest : DefaultTask() {
    @get:InputFile
    @get:PathSensitive(PathSensitivity.NONE)
    abstract val mergedManifest: RegularFileProperty

    /** Fully qualified class names of the services the Launcher may declare. */
    @get:Input
    abstract val allowedServices: ListProperty<String>

    @get:OutputFile
    abstract val report: RegularFileProperty

    @TaskAction
    fun check() {
        val androidNs = "http://schemas.android.com/apk/res/android"
        val manifest = DocumentBuilderFactory.newInstance()
            .apply { isNamespaceAware = true }
            .newDocumentBuilder()
            .parse(mergedManifest.get().asFile)
        fun names(tag: String): List<String> {
            val nodes = manifest.getElementsByTagName(tag)
            return (0 until nodes.length).map {
                (nodes.item(it) as org.w3c.dom.Element).getAttributeNS(androidNs, "name")
            }
        }

        val problems = buildList {
            if ("android.permission.INTERNET" in names("uses-permission")) {
                add("has the INTERNET permission")
            }
            names("receiver").forEach { add("declares the receiver $it") }
            names("service").filterNot { it in allowedServices.get() }
                .forEach { add("declares the service $it") }
        }
        val file = mergedManifest.get().asFile
        if (problems.isNotEmpty()) {
            throw GradleException("The Launcher's merged manifest ($file):\n- " + problems.joinToString("\n- "))
        }
        report.get().asFile.writeText("OK: $file\n")
    }
}

/** Copies the fake apps' release APKs into a folder the UI tests ship as assets. */
abstract class CollectFakeAppApks : DefaultTask() {
    @get:InputFiles
    @get:PathSensitive(PathSensitivity.NAME_ONLY)
    abstract val apks: ConfigurableFileCollection

    @get:OutputDirectory
    abstract val outputDir: DirectoryProperty

    @get:Inject
    abstract val files: FileSystemOperations

    @TaskAction
    fun collect() {
        files.sync {
            from(apks)
            into(outputDir)
            // Flat, so each APK is an asset named after its file.
            eachFile { path = name }
            includeEmptyDirs = false
        }
    }
}

val fakeAppApks = tasks.register<CollectFakeAppApks>("collectFakeAppApks") {
    // A file tree, walked when the task runs. A set of files would be fixed when the configuration
    // cache is stored, before :fakeapp has built any APK, and so be empty on a clean build.
    apks.from(
        project(":fakeapp").layout.buildDirectory.dir("outputs/apk")
            .map { dir -> dir.asFileTree.matching { include("*/release/*.apk") } },
    )
    apks.builtBy(":fakeapp:assembleRelease")
}

androidComponents {
    onVariants { variant ->
        val variantName = variant.name.replaceFirstChar { it.uppercase() }
        val checkManifest = tasks.register<CheckLauncherManifest>("check${variantName}LauncherManifest") {
            mergedManifest.set(variant.artifacts.get(SingleArtifact.MERGED_MANIFEST))
            // The Idle Screen, the TV's screensaver, is the one service the Launcher may run.
            allowedServices.set(listOf("io.github.danajerban.fuegoos.IdleScreen"))
            report.set(layout.buildDirectory.file("reports/launcher-manifest/${variant.name}.txt"))
        }
        tasks.named { it == "check" || it == "assemble$variantName" }.configureEach { dependsOn(checkManifest) }

        variant.deviceTests.values.forEach { deviceTest ->
            deviceTest.sources.assets?.addGeneratedSourceDirectory(fakeAppApks, CollectFakeAppApks::outputDir)
        }
    }
}
