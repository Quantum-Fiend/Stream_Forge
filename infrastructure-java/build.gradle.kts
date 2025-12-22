plugins {
    id("java-library")
}

dependencies {
    // Shared models
    implementation(project(":shared-models"))
    
    // Logging
    implementation("org.slf4j:slf4j-api:2.0.9")
    implementation("ch.qos.logback:logback-classic:1.4.11")
    
    // Apache Curator for ZooKeeper coordination
    implementation("org.apache.curator:curator-framework:5.5.0")
    implementation("org.apache.curator:curator-recipes:5.5.0")
    
    // RocksDB for state storage
    implementation("org.rocksdb:rocksdbjni:8.5.3")
    
    // Jackson for serialization
    implementation("com.fasterxml.jackson.core:jackson-databind:2.15.2")
    implementation("com.fasterxml.jackson.datatype:jackson-datatype-jsr310:2.15.2")
    
    // Metrics
    implementation("io.micrometer:micrometer-core:1.11.5")
    
    // Testing
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.0")
    testImplementation("org.mockito:mockito-core:5.5.0")
    testImplementation("org.assertj:assertj-core:3.24.2")
}
