// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract LigtasLinkAudit {
    struct AnchorRecord {
        bytes32 merkleRoot;
        string workerId;
        uint256 timestamp;
        uint256 batchSize;
        bool exists;
    }

    mapping(bytes32 => AnchorRecord) public anchors;

    event BatchAnchored(bytes32 indexed merkleRoot, string workerId, uint256 batchSize, uint256 timestamp);
    event TamperRejected(bytes32 indexed computedRoot, bytes32 indexed claimedRoot, string reason);

    function anchorBatchState(
        bytes32 claimedRoot,
        bytes32 recomputedRoot,
        string memory workerId,
        uint256 batchSize
    ) external returns (bool) {
        if (claimedRoot != recomputedRoot) {
            emit TamperRejected(recomputedRoot, claimedRoot, "Tamper Detected: Root mismatch.");
            return false;
        }

        require(!anchors[claimedRoot].exists, "Error: Root already anchored.");

        anchors[claimedRoot] = AnchorRecord({
            merkleRoot: claimedRoot,
            workerId: workerId,
            timestamp: block.timestamp,
            batchSize: batchSize,
            exists: true
        });

        emit BatchAnchored(claimedRoot, workerId, batchSize, block.timestamp);
        return true;
    }
}
