package com.streamforge.infra.cluster;

import org.apache.curator.framework.CuratorFramework;
import org.apache.curator.framework.CuratorFrameworkFactory;
import org.apache.curator.framework.recipes.leader.LeaderLatch;
import org.apache.curator.framework.recipes.nodes.PersistentNode;
import org.apache.curator.retry.ExponentialBackoffRetry;
import org.apache.zookeeper.CreateMode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.Closeable;
import java.io.IOException;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Cluster coordination using Apache Curator and ZooKeeper
 * Handles node registration, leader election, and membership tracking
 */
public class ClusterCoordinator implements Closeable {
    private static final Logger logger = LoggerFactory.getLogger(ClusterCoordinator.class);
    private static final String CLUSTER_PATH = "/streamforge/cluster";
    private static final String NODES_PATH = CLUSTER_PATH + "/nodes";
    private static final String LEADER_PATH = CLUSTER_PATH + "/leader";
    
    private final CuratorFramework curator;
    private final String nodeId;
    private final LeaderLatch leaderLatch;
    private final PersistentNode nodeRegistration;
    private final Map<String, NodeInfo> clusterNodes;
    
    public ClusterCoordinator(String zkConnectionString, String nodeId) {
        this.nodeId = nodeId;
        this.clusterNodes = new ConcurrentHashMap<>();
        
        // Initialize Curator framework
        this.curator = CuratorFrameworkFactory.builder()
            .connectString(zkConnectionString)
            .retryPolicy(new ExponentialBackoffRetry(1000, 3))
            .namespace("streamforge")
            .build();
        
        curator.start();
        
        try {
            // Ensure base paths exist
            ensurePath(CLUSTER_PATH);
            ensurePath(NODES_PATH);
            
            // Register this node
            String nodePath = NODES_PATH + "/" + nodeId;
            NodeInfo nodeInfo = new NodeInfo(nodeId, System.currentTimeMillis());
            byte[] nodeData = serializeNodeInfo(nodeInfo);
            
            this.nodeRegistration = new PersistentNode(
                curator,
                CreateMode.EPHEMERAL,
                false,
                nodePath,
                nodeData
            );
            nodeRegistration.start();
            
            // Start leader election
            this.leaderLatch = new LeaderLatch(curator, LEADER_PATH, nodeId);
            leaderLatch.start();
            
            // Watch for cluster changes
            watchClusterNodes();
            
            logger.info("ClusterCoordinator initialized for node {}", nodeId);
            
        } catch (Exception e) {
            throw new RuntimeException("Failed to initialize cluster coordinator", e);
        }
    }
    
    /**
     * Check if this node is the cluster leader
     */
    public boolean isLeader() {
        return leaderLatch.hasLeadership();
    }
    
    /**
     * Get the current leader node ID
     */
    public Optional<String> getLeader() {
        try {
            return Optional.ofNullable(leaderLatch.getLeader().getId());
        } catch (Exception e) {
            logger.error("Failed to get leader", e);
            return Optional.empty();
        }
    }
    
    /**
     * Get all active nodes in the cluster
     */
    public List<NodeInfo> getActiveNodes() {
        try {
            List<String> children = curator.getChildren().forPath(NODES_PATH);
            List<NodeInfo> nodes = new ArrayList<>();
            
            for (String child : children) {
                try {
                    byte[] data = curator.getData().forPath(NODES_PATH + "/" + child);
                    NodeInfo nodeInfo = deserializeNodeInfo(data);
                    nodes.add(nodeInfo);
                } catch (Exception e) {
                    logger.warn("Failed to get data for node {}", child, e);
                }
            }
            
            return nodes;
        } catch (Exception e) {
            logger.error("Failed to get active nodes", e);
            return Collections.emptyList();
        }
    }
    
    /**
     * Get count of active nodes
     */
    public int getNodeCount() {
        return getActiveNodes().size();
    }
    
    /**
     * Register a callback for leadership changes
     */
    public void onLeadershipChange(LeadershipListener listener) {
        leaderLatch.addListener(new org.apache.curator.framework.recipes.leader.LeaderLatchListener() {
            @Override
            public void isLeader() {
                listener.onBecomeLeader(nodeId);
            }
            
            @Override
            public void notLeader() {
                listener.onLoseLeadership(nodeId);
            }
        });
    }
    
    /**
     * Distribute a value across nodes using consistent hashing
     */
    public String selectNodeForKey(String key) {
        List<NodeInfo> nodes = getActiveNodes();
        if (nodes.isEmpty()) {
            return nodeId; // Fallback to current node
        }
        
        // Simple hash-based selection
        int hash = Math.abs(key.hashCode());
        int index = hash % nodes.size();
        return nodes.get(index).nodeId;
    }
    
    private void watchClusterNodes() {
        try {
            curator.getChildren().watched().forPath(NODES_PATH);
            curator.getCuratorListenable().addListener((client, event) -> {
                switch (event.getType()) {
                    case CHILDREN_CHANGED:
                        logger.info("Cluster topology changed");
                        break;
                    case CONNECTION_LOST:
                        logger.warn("Connection to ZooKeeper lost");
                        break;
                    case RECONNECTED:
                        logger.info("Reconnected to ZooKeeper");
                        break;
                }
            });
        } catch (Exception e) {
            logger.error("Failed to watch cluster nodes", e);
        }
    }
    
    private void ensurePath(String path) throws Exception {
        if (curator.checkExists().forPath(path) == null) {
            curator.create()
                .creatingParentsIfNeeded()
                .forPath(path);
        }
    }
    
    private byte[] serializeNodeInfo(NodeInfo nodeInfo) {
        String json = String.format(
            "{\"nodeId\":\"%s\",\"startTime\":%d}",
            nodeInfo.nodeId,
            nodeInfo.startTime
        );
        return json.getBytes();
    }
    
    private NodeInfo deserializeNodeInfo(byte[] data) {
        String json = new String(data);
        // Simple JSON parsing (in production, use Jackson)
        String nodeId = json.split("\"nodeId\":\"")[1].split("\"")[0];
        long startTime = Long.parseLong(json.split("\"startTime\":")[1].split("}")[0]);
        return new NodeInfo(nodeId, startTime);
    }
    
    @Override
    public void close() throws IOException {
        try {
            if (leaderLatch != null) {
                leaderLatch.close();
            }
            if (nodeRegistration != null) {
                nodeRegistration.close();
            }
            if (curator != null) {
                curator.close();
            }
        } catch (Exception e) {
            throw new IOException("Failed to close cluster coordinator", e);
        }
    }
    
    public static class NodeInfo {
        public final String nodeId;
        public final long startTime;
        
        public NodeInfo(String nodeId, long startTime) {
            this.nodeId = nodeId;
            this.startTime = startTime;
        }
    }
    
    public interface LeadershipListener {
        void onBecomeLeader(String nodeId);
        void onLoseLeadership(String nodeId);
    }
}
