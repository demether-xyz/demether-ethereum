const { network } = require("hardhat");
const { upgrader, getDependencies, dependenciesDeployer } = require("../scripts/deployer");

async function main() {
  const list = ["messenger"];
  let dependencies = await getDependencies(list, network.name);

  await dependenciesDeployer({
    name: "messenger",
    params: {
      name: "Messenger",
      address: dependencies.messenger,
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
