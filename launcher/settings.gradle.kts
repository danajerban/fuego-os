pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode = RepositoriesMode.FAIL_ON_PROJECT_REPOS
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "fuego-launcher"

include(":app")
// Test-only stand-ins for the Dock's apps, installed on the emulator by the UI tests.
include(":fakeapp")
