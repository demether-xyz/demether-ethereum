const { network } = require("hardhat");
const { deployer, getDependencies, dependenciesDeployer } = require("./deployer");

function getSettings(network) {
  switch (network) {
    case "mainnet":
      return {
        owner: "0xCFf65f5617cc5ed358bB7AC95eF6F75BdAA23D67",
        service: "0x20dF03A9EF9A72aC4f77Afb1Ca6e96846FCB0015",
      };
  }
}

async function main() {
  const list = ["deposits_manager_L1"];
  let dependencies = await getDependencies(list, network.name);
  const settings = getSettings(network.name);

  await dependenciesDeployer({
    name: "liquidity_pool",
    params: {
      name: "LiquidityPool",
      isProxy: true,
      params: [dependencies.deposits_manager_L1, settings.owner, settings.service],
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
