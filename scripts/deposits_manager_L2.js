const { network } = require("hardhat");
const { deployer, getDependencies, dependenciesDeployer } = require("./deployer");

function getSettings(network) {
  switch (network) {
    case "arbitrum":
      return {
        weth: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
        owner: "0x0Fb539EEBE2ED7b69F0534FD01853F34C8A74254",
        service: "0x19D6bAC96A5536f76C3F697B94F4dEE8aB628bb2",
        native: true,
      };
  }
}

async function main() {
  const list = [];
  let dependencies = await getDependencies(list, network.name);
  const settings = getSettings(network.name);

  await dependenciesDeployer({
    name: "deposits_manager_L2",
    params: {
      name: "DepositsManagerL2",
      isProxy: true,
      params: [settings.weth, settings.owner, settings.service, settings.native],
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
