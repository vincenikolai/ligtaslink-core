// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract LigtasLinkAudit {
    enum Status { VERIFIED, REJECTED_TAMPERED }
    struct Batch { bytes32 root; string workerId; uint256 batchSize; uint256 timestamp; }
    mapping(bytes32 => Batch) public batches;
    event BatchAnchored(bytes32 indexed batchId, bytes32 indexed root, string workerId, uint256 batchSize);
    event TamperRejected(bytes32 indexed batchId, bytes32 claimedRoot, bytes32 recomputedRoot, string workerId);

    function anchorBatchState(
        bytes32 claimedRoot,
        bytes32 recomputedRoot,
        string calldata workerId,
        uint256 batchSize
    ) external returns (Status status) {
        bytes32 batchId = keccak256(abi.encode(claimedRoot, workerId, block.number));
        if (claimedRoot != recomputedRoot) {
            emit TamperRejected(batchId, claimedRoot, recomputedRoot, workerId);
            return Status.REJECTED_TAMPERED;
        }
        require(batchSize > 0, "empty batch");
        batches[batchId] = Batch(claimedRoot, workerId, batchSize, block.timestamp);
        emit BatchAnchored(batchId, claimedRoot, workerId, batchSize);
        return Status.VERIFIED;
    }
}
