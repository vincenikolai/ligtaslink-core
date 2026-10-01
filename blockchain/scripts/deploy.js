const hre = require("hardhat");
async function main() {
  const Audit = await hre.ethers.getContractFactory("LigtasLinkAudit");
  const audit = await Audit.deploy();
  await audit.waitForDeployment();
  console.log(`LigtasLinkAudit deployed to ${await audit.getAddress()}`);
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
