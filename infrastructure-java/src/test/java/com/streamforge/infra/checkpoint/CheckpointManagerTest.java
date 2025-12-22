package com.streamforge.infra.checkpoint;

import org.junit.jupiter.api.*;
import static org.assertj.core.api.Assertions.*;
import java.io.File;
import java.util.*;

class CheckpointManagerTest {
    
    private static final String TEST_DATA_DIR = "build/test-data";
    private CheckpointManager checkpointManager;
    
    @BeforeEach
    void setUp() throws Exception {
        new File(TEST_DATA_DIR).mkdirs();
        checkpointManager = new CheckpointManager(TEST_DATA_DIR);
    }
    
    @AfterEach
    void tearDown() {
        if (checkpointManager != null) {
            checkpointManager.close();
        }
        deleteDirectory(new File(TEST_DATA_DIR));
    }
    
    @Test
    void shouldCreateCheckpoint() {
        String jobId = "test-job-001";
        long offset = 1000L;
        Map<String, byte[]> state = Map.of(
            "key1", "value1".getBytes(),
            "key2", "value2".getBytes()
        );
        
        var checkpoint = checkpointManager.createCheckpoint(jobId, offset, state);
        
        assertThat(checkpoint).isNotNull();
        assertThat(checkpoint.getJobId()).isEqualTo(jobId);
        assertThat(checkpoint.getOffset()).isEqualTo(offset);
    }
    
    @Test
    void shouldRestoreLatestCheckpoint() {
        String jobId = "test-job-002";
        Map<String, byte[]> state = Map.of("key", "value".getBytes());
        
        checkpointManager.createCheckpoint(jobId, 100, state);
        checkpointManager.createCheckpoint(jobId, 200, state);
        checkpointManager.createCheckpoint(jobId, 300, state);
        
        var restored = checkpointManager.restoreLatest(jobId);
        
        assertThat(restored).isPresent();
        assertThat(restored.get().getOffset()).isEqualTo(300);
    }
    
    @Test
    void shouldReturnEmptyWhenNoCheckpoint() {
        var restored = checkpointManager.restoreLatest("non-existent-job");
        assertThat(restored).isEmpty();
    }
    
    @Test
    void shouldListCheckpointsForJob() {
        String jobId = "test-job-003";
        Map<String, byte[]> state = Map.of("key", "value".getBytes());
        
        checkpointManager.createCheckpoint(jobId, 100, state);
        checkpointManager.createCheckpoint(jobId, 200, state);
        
        var checkpoints = checkpointManager.listCheckpoints(jobId);
        
        assertThat(checkpoints).hasSize(2);
    }
    
    private void deleteDirectory(File dir) {
        if (dir.exists()) {
            File[] files = dir.listFiles();
            if (files != null) {
                for (File file : files) {
                    if (file.isDirectory()) {
                        deleteDirectory(file);
                    }
                    file.delete();
                }
            }
            dir.delete();
        }
    }
}
