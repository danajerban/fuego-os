// Test-only stand-ins for the Dock's apps. Each flavour is a tiny TV app that carries the real app's
// package name, so the UI tests can install it on an emulator that has no Netflix, Stremio or Spotify
// and check that its tile opens it. The tvinputs and inputplayer flavours stand in for the TV's HDMI
// inputs and the TV input player that switches to them.
// Never shipped: only the Launcher's UI tests use these APKs.
plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "io.github.danajerban.fuegoos.fakeapp"
    compileSdk = 34

    defaultConfig {
        minSdk = 34
        targetSdk = 34
        versionCode = 1
        versionName = "1"
        // Each Dock app's fake has an icon of its own colour (see DockApp in the UI tests); others are grey.
        resValue("color", "icon", "#808080")
    }

    buildFeatures {
        resValues = true
    }

    flavorDimensions += "dockApp"
    productFlavors {
        create("netflix") {
            dimension = "dockApp"
            applicationId = "com.netflix.ninja"
            resValue("string", "app_name", "Fake Netflix")
            resValue("color", "icon", "#E50914")
        }
        create("youtube") {
            dimension = "dockApp"
            applicationId = "com.google.android.youtube.tv"
            resValue("string", "app_name", "Fake YouTube")
            resValue("color", "icon", "#FF0033")
        }
        create("stremio") {
            dimension = "dockApp"
            applicationId = "com.stremio.one"
            resValue("string", "app_name", "Fake Stremio")
            resValue("color", "icon", "#7B5BF5")
        }
        create("spotify") {
            dimension = "dockApp"
            applicationId = "com.spotify.tv.android"
            resValue("string", "app_name", "Fake Spotify")
            resValue("color", "icon", "#1DB954")
        }
        // The TV's inputs, which the emulator lacks: HDMI ports for the Inputs screen to list.
        create("tvinputs") {
            dimension = "dockApp"
            applicationId = "io.github.danajerban.fuegoos.faketvinputs"
            resValue("string", "app_name", "Fake TV inputs")
        }
        // The TV input player, which the emulator lacks: it shows which input it was asked to play.
        create("inputplayer") {
            dimension = "dockApp"
            applicationId = "com.google.android.tv.inputplayer"
            resValue("string", "app_name", "Fake TV input player")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
