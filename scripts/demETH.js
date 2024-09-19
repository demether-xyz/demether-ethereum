const { network } = require("hardhat");
const { deployer, getDependencies, dependenciesDeployer } = require("./deployer");

/*
IMPORTANT: Deployer account must have used Nonce 4. For addresses to match

LayerZero
https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts
 */

function getSettings(network) {
  switch (network) {
    case "mainnet":
      return {
        owner: "0xCFf65f5617cc5ed358bB7AC95eF6F75BdAA23D67",
        layerzero: "0x1a44076050125825900e736c501f859c50fE728c",
      };
    case "arbitrum":
      return {
        owner: "0x0Fb539EEBE2ED7b69F0534FD01853F34C8A74254",
        layerzero: "0x1a44076050125825900e736c501f859c50fE728c",
      };
    case "sepolia":
      return {
        owner: "0x4C0301d076D90468143C2065BBBC78149f1FcAF1",
        layerzero: "0x6EDCE65403992e310A62460808c4b910D972f10f",
      };
    case "morph_holesky":
      return {
        owner: "0x4C0301d076D90468143C2065BBBC78149f1FcAF1",
        layerzero: "0x6C7Ab2202C98C4227C5c46f1417D81144DA716Ff",
      };
    case "celo_alfajores":
      return {
        owner: "0x4C0301d076D90468143C2065BBBC78149f1FcAF1",
        layerzero: "0x6EDCE65403992e310A62460808c4b910D972f10f",
      };
  }
}

async function main() {
  const deposit_manager = ["mainnet", "sepolia"].includes(network.name) ? "deposits_manager_L1" : "deposits_manager_L2";
  const list = [deposit_manager];
  let dependencies = await getDependencies(list, network.name);
  const settings = getSettings(network.name);
  const deposit_manager_address = deposit_manager in dependencies ? dependencies[deposit_manager] : settings.owner;

  await dependenciesDeployer({
    name: "demETH",
    params: {
      name: "DOFT",
      isProxy: true,
      params: ["Demether ETH", "demETH", settings.owner, deposit_manager_address],
      options: { constructorArgs: [settings.layerzero], unsafeAllow: ["state-variable-immutable", "constructor"] },
    },
    deployerFunction: deployer,
    dependencies,
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
