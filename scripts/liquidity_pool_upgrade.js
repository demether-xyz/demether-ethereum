const { network } = require("hardhat");
const { upgrader, getDependencies, dependenciesDeployer } = require("../scripts/deployer");

async function main() {
  const list = ["liquidity_pool"];
  let dependencies = await getDependencies(list, network.name);

  await dependenciesDeployer({
    name: "liquidity_pool",
    params: {
      name: "LiquidityPool",
      address: dependencies.liquidity_pool,
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
