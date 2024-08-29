const { network } = require("hardhat");
const { upgrader, getDependencies, dependenciesDeployer } = require("../scripts/deployer");

async function main() {
  const list = ["deposits_manager_L2"];
  let dependencies = await getDependencies(list, network.name);

  await dependenciesDeployer({
    name: "deposits_manager_L2",
    params: {
      name: "DepositsManagerL2",
      address: dependencies.deposits_manager_L2,
    },
    deployerFunction: upgrader,
    dependencies,
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
