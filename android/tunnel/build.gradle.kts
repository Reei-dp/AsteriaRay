@file:Suppress("UnstableApiUsage")

import org.gradle.api.tasks.testing.logging.TestLogEvent

val pkg: String = providers.gradleProperty("amneziawgPackageName").get()
val cmakeAndroidPackageName: String = providers.environmentVariable("ANDROID_PACKAGE_NAME").getOrElse(pkg)
val tunnelNdk: String =
    providers.gradleProperty("tunnel.ndkVersion").orElse("28.2.13676358").get()

plugins {
    id("com.android.library")
}

android {
    // Match Flutter’s default NDK; override with -Ptunnel.ndkVersion=… or android/gradle.properties.
    // Avoids AGP picking another side-by-side NDK (e.g. broken 27.x without source.properties).
    ndkVersion = tunnelNdk
    compileSdk = 35
    defaultConfig {
        minSdk = 24
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    namespace = "${pkg}.tunnel"
    externalNativeBuild {
        cmake {
            path("tools/CMakeLists.txt")
        }
    }
    testOptions.unitTests.all {
        it.testLogging { events(TestLogEvent.PASSED, TestLogEvent.SKIPPED, TestLogEvent.FAILED) }
    }
    buildTypes {
        all {
            externalNativeBuild {
                cmake {
                    targets("libwg-go.so", "libwg.so", "libwg-quick.so")
                    arguments("-DGRADLE_USER_HOME=${project.gradle.gradleUserHomeDir}")
                }
            }
        }
        release {
            externalNativeBuild {
                cmake {
                    arguments("-DANDROID_PACKAGE_NAME=${cmakeAndroidPackageName}")
                }
            }
        }
        debug {
            externalNativeBuild {
                cmake {
                    // Must match host app applicationId. Flutter uses the same id for debug/release
                    // (no applicationIdSuffix); upstream uses ".debug" only when the app does too.
                    arguments("-DANDROID_PACKAGE_NAME=${cmakeAndroidPackageName}")
                }
            }
        }
    }
    lint {
        disable += "LongLogTag"
        disable += "NewApi"
    }
}

dependencies {
    implementation("androidx.annotation:annotation:1.7.1")
    implementation("androidx.collection:collection:1.4.0")
    compileOnly("com.google.code.findbugs:jsr305:3.0.2")
    testImplementation("junit:junit:4.13.2")
}
