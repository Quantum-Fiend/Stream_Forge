plugins {
    id("java")
    id("org.jetbrains.kotlin.jvm") version "1.9.21" apply false
}

allprojects {
    group = "com.streamforge"
    version = "1.0.0"

    repositories {
        mavenCentral()
    }
}

subprojects {
    apply(plugin = "java")
    
    java {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    tasks.withType<Test> {
        useJUnitPlatform()
    }
}
