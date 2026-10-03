const fs = require("fs");
const path = require("path");
const hre = require("hardhat");

async function main() {
  const { chainId } = await hre.ethers.provider.getNetwork();
  if (chainId !== 31337n) throw new Error(`Expected Hardhat chainId 31337, connected to ${chainId}`);

  const Audit = await hre.ethers.getContractFactory("LigtasLinkAudit");
  const audit = await Audit.deploy();
  await audit.waitForDeployment();
  const address = await audit.getAddress();

  // The Dual-Sync Daemon reads this file to locate the contract and its ABI.
  const artifact = await hre.artifacts.readArtifact("LigtasLinkAudit");
  const outDir = path.join(__dirname, "..", "deployments");
  fs.mkdirSync(outDir, { recursive: true });
  const outFile = path.join(outDir, `${hre.network.name}.json`);
  fs.writeFileSync(outFile, JSON.stringify({
    contract: "LigtasLinkAudit",
    address,
    chainId: Number(chainId),
    network: hre.network.name,
    deployedAt: new Date().toISOString(),
    abi: artifact.abi,
  }, null, 2));

  console.log(`LigtasLinkAudit deployed to ${address} (chainId ${chainId})`);
  console.log(`Deployment manifest written to ${outFile}`);
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
