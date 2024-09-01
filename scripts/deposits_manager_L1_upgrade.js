const { network } = require("hardhat");
const { upgrader, getDependencies, dependenciesDeployer } = require("../scripts/deployer");

async function main() {
  const list = ["deposits_manager_L1"];
  let dependencies = await getDependencies(list, network.name);

  await dependenciesDeployer({
    name: "deposits_manager_L1",
    params: {
      name: "DepositsManagerL1",
      address: dependencies.deposits_manager_L1,
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
