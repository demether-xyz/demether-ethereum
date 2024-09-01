const { network } = require("hardhat");
const { deployer, getDependencies, dependenciesDeployer } = require("./deployer");

async function main() {
  const list = ["deposits_manager_L1"];
  let dependencies = await getDependencies(list, network.name);

  await dependenciesDeployer({
    name: "vault",
    params: {
      name: "ClaimsVault",
      isProxy: false,
      params: [dependencies.deposits_manager_L1],
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
