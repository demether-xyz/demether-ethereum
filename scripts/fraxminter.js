const { network } = require("hardhat");
const { deployer, getDependencies, dependenciesDeployer } = require("./deployer");

async function main() {
  const list = [];
  let dependencies = await getDependencies(list, network.name);

  await dependenciesDeployer({
    name: "fraxminter",
    params: {
      name: "MockFrxETHMinter",
      isProxy: false,
      params: [],
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
