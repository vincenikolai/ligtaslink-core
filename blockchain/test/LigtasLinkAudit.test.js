const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LigtasLinkAudit", () => {
  const rootA = ethers.sha256(ethers.toUtf8Bytes("batch-a"));
  const rootB = ethers.sha256(ethers.toUtf8Bytes("batch-b"));
  let audit;

  beforeEach(async () => {
    audit = await (await ethers.getContractFactory("LigtasLinkAudit")).deploy();
  });

  it("anchors a batch when the claimed and recomputed roots match", async () => {
    expect(await audit.anchorBatchState.staticCall(rootA, rootA, "W-01", 12)).to.equal(true);
    await expect(audit.anchorBatchState(rootA, rootA, "W-01", 12))
      .to.emit(audit, "BatchAnchored")
      .withArgs(rootA, "W-01", 12, (ts) => ts > 0n);
    const record = await audit.anchors(rootA);
    expect(record.exists).to.equal(true);
    expect(record.workerId).to.equal("W-01");
    expect(record.batchSize).to.equal(12n);
  });

  it("rejects a tampered batch without storing it", async () => {
    expect(await audit.anchorBatchState.staticCall(rootA, rootB, "W-01", 12)).to.equal(false);
    await expect(audit.anchorBatchState(rootA, rootB, "W-01", 12))
      .to.emit(audit, "TamperRejected")
      .withArgs(rootB, rootA, "Tamper Detected: Root mismatch.");
    expect((await audit.anchors(rootA)).exists).to.equal(false);
  });

  it("refuses to anchor the same root twice", async () => {
    await audit.anchorBatchState(rootA, rootA, "W-01", 3);
    await expect(audit.anchorBatchState(rootA, rootA, "W-02", 3))
      .to.be.revertedWith("Error: Root already anchored.");
  });
});
