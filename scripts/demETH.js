const { network } = require("hardhat");
const { deployer, getDependencies, dependenciesDeployer } = require("./deployer");

/*
IMPORTANT: Deployer account must have used Nonce 4. For addresses to match
 */

function getSettings(network) {
  switch (network) {
    case "mainnet":
      return {
        owner: "0xCFf65f5617cc5ed358bB7AC95eF6F75BdAA23D67",
        layerzero: "0x1a44076050125825900e736c501f859c50fE728c", // https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts
      };
    case "arbitrum":
      return {
        owner: "0x0Fb539EEBE2ED7b69F0534FD01853F34C8A74254",
        layerzero: "0x1a44076050125825900e736c501f859c50fE728c",
      };
  }
}

async function main() {
  const deposit_manager = network.name === "mainnet" ? "deposits_manager_L1" : "deposits_manager_L2";
  const list = [deposit_manager];
  const name = network.name === "mainnet" ? "demETH_L1" : "demETH_" + network.name;
  let dependencies = await getDependencies(list, network.name);
  const settings = getSettings(network.name);

  await dependenciesDeployer({
    name: name,
    params: {
      name: "DOFT",
      isProxy: true,
      params: ["Demether ETH", "demETH", settings.owner, dependencies[deposit_manager]],
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
