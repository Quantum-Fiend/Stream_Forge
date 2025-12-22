plugins {
    scala
    id("java-library")
}

dependencies {
    // Shared models
    implementation(project(":shared-models"))
    implementation(project(":infrastructure-java"))
    
    // Scala
    implementation("org.scala-lang:scala3-library_3:3.3.1")
    
    // Akka Streams for reactive processing
    implementation("com.typesafe.akka:akka-stream_2.13:2.8.5")
    implementation("com.typesafe.akka:akka-actor-typed_2.13:2.8.5")
    
    // Reactive Streams
    implementation("org.reactivestreams:reactive-streams:1.0.4")
    
    // Logging
    implementation("org.slf4j:slf4j-api:2.0.9")
    implementation("ch.qos.logback:logback-classic:1.4.11")
    
    // Cats for functional programming
    implementation("org.typelevel:cats-core_2.13:2.10.0")
    
    // Config
    implementation("com.typesafe:config:1.4.3")
    
    // Testing
    testImplementation("org.scalatest:scalatest_2.13:3.2.17")
    testImplementation("com.typesafe.akka:akka-stream-testkit_2.13:2.8.5")
}

tasks.withType<ScalaCompile> {
    scalaCompileOptions.additionalParameters = listOf(
        "-deprecation",
        "-feature"
    )
}
