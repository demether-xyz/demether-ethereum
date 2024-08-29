const { network } = require("hardhat");
const { deployer, getDependencies, dependenciesDeployer } = require("./deployer");

function getSettings(network) {
  switch (network) {
    case "sepolia":
      return {
        owner: "0xCFf65f5617cc5ed358bB7AC95eF6F75BdAA23D67",
        service: "0x20dF03A9EF9A72aC4f77Afb1Ca6e96846FCB0015",
      };
    case "mainnet":
      return {
        owner: "0xCFf65f5617cc5ed358bB7AC95eF6F75BdAA23D67",
        service: "0x20dF03A9EF9A72aC4f77Afb1Ca6e96846FCB0015",
      };
  }
}

async function main() {
  const list = [];
  let dependencies = await getDependencies(list, network.name);
  const settings = getSettings(network.name);

  await dependenciesDeployer({
    name: "deposits_manager_L1",
    params: {
      name: "DepositsManagerL1",
      isProxy: true,
      params: [settings.owner, settings.service],
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
