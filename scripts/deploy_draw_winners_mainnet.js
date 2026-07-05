// scripts/deploy_draw_winners_mainnet.js
const hre = require("hardhat");
require("dotenv").config();

async function main() {
  // =========================
  // PARAMETRI ASSET
  // =========================
  const NAME = "Birra20Venti Draw Winners";
  const SYMBOL = "B20V-DRAW";

  // UP di Birra20Venti (MAINNET) — diventerà owner della collezione
  const UP_OWNER = "0x1d62B8d2c63B942095AD3C7FFc7e845195D9E718"; // Birra20Venti

  // Controller EOA (extension desktop) - deve essere il signer usato per il deploy
  const EXPECTED_CONTROLLER = "0x9C8Fd044A4C777f9f97c6cFC127C91f86b795C9c";

  // =========================
  // PRECHECK
  // =========================
  const [deployer] = await hre.ethers.getSigners();

  console.log("Network:", hre.network.name);
  console.log("Deployer (tx signer):", deployer.address);
  console.log("Expected controller:", EXPECTED_CONTROLLER);
  console.log("UP owner:", UP_OWNER);

  const net = await hre.ethers.provider.getNetwork();
  const chainId = Number(net.chainId);
  console.log("Chain ID:", chainId);

  if (chainId !== 42) {
    throw new Error(
      `ChainId non atteso: ${chainId}. Atteso 42 (LUKSO Mainnet). Interrotto.`
    );
  }

  if (deployer.address.toLowerCase() !== EXPECTED_CONTROLLER.toLowerCase()) {
    throw new Error(
      `Signer diverso dal controller atteso.\n` +
        `Signer: ${deployer.address}\n` +
        `Atteso: ${EXPECTED_CONTROLLER}\n` +
        `Rischio deploy con account sbagliato. Interrotto.`
    );
  }

  // Verifica che UP_OWNER sia un contratto (UP vero)
  const code = await hre.ethers.provider.getCode(UP_OWNER);
  if (!code || code === "0x") {
    throw new Error(
      "UP_OWNER non è un contratto (code=0x). Hai incollato un EOA, non un UP."
    );
  }

  const bal = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Controller balance (LYX):", hre.ethers.formatEther(bal));

  if (bal < hre.ethers.parseEther("0.05")) {
    throw new Error("Saldo controller troppo basso per un deploy sicuro su mainnet.");
  }

  // =========================
  // DEPLOY
  // =========================
  const Factory = await hre.ethers.getContractFactory("Birra20VentiDrawWinners");

  console.log("Deploying Birra20VentiDrawWinners on LUKSO Mainnet...");
  const contract = await Factory.deploy(NAME, SYMBOL, UP_OWNER);

  await contract.waitForDeployment();
  const address = await contract.getAddress();

  console.log("Deployed to:", address);

  const tx = contract.deploymentTransaction?.();
  if (tx?.hash) console.log("Deploy tx hash:", tx.hash);

  console.log(
    "OK: deploy completato. Nessun token ancora coniato (supply parte da 0).\n" +
    "Prossimo step: usare mint_draw_winner_up.js per coniare il primo premio."
  );
}

main().catch((error) => {
  console.error("DEPLOY ERROR:", error?.message || error);
  process.exitCode = 1;
});
