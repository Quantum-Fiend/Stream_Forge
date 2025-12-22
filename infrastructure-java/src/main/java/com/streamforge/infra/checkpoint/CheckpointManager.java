package com.streamforge.infra.checkpoint;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.streamforge.models.Checkpoint;
import org.rocksdb.Options;
import org.rocksdb.RocksDB;
import org.rocksdb.RocksDBException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.IOException;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Manages checkpoint creation, persistence, and recovery
 * Ensures exactly-once processing semantics
 */
public class CheckpointManager {
    private static final Logger logger = LoggerFactory.getLogger(CheckpointManager.class);
    private static final String CHECKPOINT_DIR = "checkpoints";

    private final RocksDB checkpointDb;
    private final ObjectMapper mapper;
    private final Map<String, CheckpointMetadata> checkpointCache;

    static {
        RocksDB.loadLibrary();
    }

    public CheckpointManager(String dataDir) throws RocksDBException {
        File dir = new File(dataDir, CHECKPOINT_DIR);
        if (!dir.exists()) {
            dir.mkdirs();
        }

        Options options = new Options()
                .setCreateIfMissing(true)
                .setMaxBackgroundJobs(4)
                .setWriteBufferSize(64 * 1024 * 1024); // 64MB

        this.checkpointDb = RocksDB.open(options, dir.getAbsolutePath());
        this.mapper = new ObjectMapper().registerModule(new JavaTimeModule());
        this.checkpointCache = new ConcurrentHashMap<>();

        logger.info("CheckpointManager initialized at {}", dir.getAbsolutePath());
    }

    /**
     * Create and persist a checkpoint
     */
    public Checkpoint createCheckpoint(String jobId, long offset, Map<String, byte[]> stateSnapshot) {
        String checkpointId = generateCheckpointId(jobId);
        Checkpoint checkpoint = new Checkpoint(
                checkpointId,
                jobId,
                Instant.now(),
                offset,
                stateSnapshot);

        try {
            // Persist checkpoint metadata
            String metadataKey = "meta:" + checkpointId;
            CheckpointMetadata metadata = new CheckpointMetadata(
                    checkpointId,
                    jobId,
                    checkpoint.getTimestamp(),
                    offset,
                    stateSnapshot.size());

            byte[] metadataBytes = mapper.writeValueAsBytes(metadata);
            checkpointDb.put(metadataKey.getBytes(), metadataBytes);

            // Persist state snapshots
            for (Map.Entry<String, byte[]> entry : stateSnapshot.entrySet()) {
                String stateKey = "state:" + checkpointId + ":" + entry.getKey();
                checkpointDb.put(stateKey.getBytes(), entry.getValue());
            }

            checkpointCache.put(jobId, metadata);
            logger.info("Created checkpoint {} for job {} at offset {}", checkpointId, jobId, offset);

            return checkpoint;

        } catch (RocksDBException | IOException e) {
            logger.error("Failed to create checkpoint for job {}", jobId, e);
            throw new CheckpointException("Failed to create checkpoint", e);
        }
    }

    /**
     * Restore state from the latest checkpoint
     */
    public Optional<Checkpoint> restoreLatest(String jobId) {
        try {
            // Find latest checkpoint for this job
            CheckpointMetadata latest = findLatestCheckpoint(jobId);
            if (latest == null) {
                logger.info("No checkpoint found for job {}", jobId);
                return Optional.empty();
            }

            // Restore state snapshots
            Map<String, byte[]> stateSnapshot = new HashMap<>();
            String prefix = "state:" + latest.checkpointId + ":";

            byte[] prefixBytes = prefix.getBytes();
            try (var iterator = checkpointDb.newIterator()) {
                iterator.seek(prefixBytes);

                while (iterator.isValid()) {
                    String key = new String(iterator.key());
                    if (!key.startsWith(prefix)) {
                        break;
                    }

                    String stateKey = key.substring(prefix.length());
                    stateSnapshot.put(stateKey, iterator.value());
                    iterator.next();
                }
            }

            Checkpoint checkpoint = new Checkpoint(
                    latest.checkpointId,
                    latest.jobId,
                    latest.timestamp,
                    latest.offset,
                    stateSnapshot);

            logger.info("Restored checkpoint {} for job {} at offset {}",
                    latest.checkpointId, jobId, latest.offset);

            return Optional.of(checkpoint);

        } catch (Exception e) {
            logger.error("Failed to restore checkpoint for job {}", jobId, e);
            return Optional.empty();
        }
    }

    /**
     * List all checkpoints for a job
     */
    public List<CheckpointMetadata> listCheckpoints(String jobId) {
        List<CheckpointMetadata> checkpoints = new ArrayList<>();
        String prefix = "meta:";

        try (var iterator = checkpointDb.newIterator()) {
            iterator.seek(prefix.getBytes());

            while (iterator.isValid()) {
                String key = new String(iterator.key());
                if (!key.startsWith(prefix)) {
                    break;
                }

                CheckpointMetadata metadata = mapper.readValue(iterator.value(), CheckpointMetadata.class);
                if (metadata.jobId.equals(jobId)) {
                    checkpoints.add(metadata);
                }
                iterator.next();
            }
        } catch (Exception e) {
            logger.error("Failed to list checkpoints for job {}", jobId, e);
        }

        checkpoints.sort(Comparator.comparing(m -> m.timestamp));
        return checkpoints;
    }

    /**
     * Delete checkpoints older than retention period
     */
    public void pruneOldCheckpoints(String jobId, long retentionMs) {
        Instant cutoff = Instant.now().minusMillis(retentionMs);
        List<CheckpointMetadata> checkpoints = listCheckpoints(jobId);

        for (CheckpointMetadata metadata : checkpoints) {
            if (metadata.timestamp.isBefore(cutoff)) {
                deleteCheckpoint(metadata.checkpointId);
            }
        }
    }

    private void deleteCheckpoint(String checkpointId) {
        try {
            // Delete metadata
            checkpointDb.delete(("meta:" + checkpointId).getBytes());

            // Delete state snapshots
            String prefix = "state:" + checkpointId + ":";
            try (var iterator = checkpointDb.newIterator()) {
                iterator.seek(prefix.getBytes());

                while (iterator.isValid()) {
                    String key = new String(iterator.key());
                    if (!key.startsWith(prefix)) {
                        break;
                    }
                    checkpointDb.delete(iterator.key());
                    iterator.next();
                }
            }

            logger.debug("Deleted checkpoint {}", checkpointId);

        } catch (RocksDBException e) {
            logger.error("Failed to delete checkpoint {}", checkpointId, e);
        }
    }

    private CheckpointMetadata findLatestCheckpoint(String jobId) {
        List<CheckpointMetadata> checkpoints = listCheckpoints(jobId);
        return checkpoints.isEmpty() ? null : checkpoints.get(checkpoints.size() - 1);
    }

    private String generateCheckpointId(String jobId) {
        return jobId + "-" + System.currentTimeMillis() + "-" + UUID.randomUUID().toString().substring(0, 8);
    }

    public void close() {
        if (checkpointDb != null) {
            checkpointDb.close();
        }
    }

    // Inner class for checkpoint metadata
    public static class CheckpointMetadata {
        public String checkpointId;
        public String jobId;
        public Instant timestamp;
        public long offset;
        public int stateCount;

        public CheckpointMetadata() {
        }

        public CheckpointMetadata(String checkpointId, String jobId, Instant timestamp, long offset, int stateCount) {
            this.checkpointId = checkpointId;
            this.jobId = jobId;
            this.timestamp = timestamp;
            this.offset = offset;
            this.stateCount = stateCount;
        }
    }

    public static class CheckpointException extends RuntimeException {
        public CheckpointException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
