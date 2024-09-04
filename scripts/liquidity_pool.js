const { network } = require("hardhat");
const { deployer, getDependencies, dependenciesDeployer } = require("./deployer");

function getSettings(network) {
  switch (network) {
    case "mainnet":
      return {
        owner: "0x4C0301d076D90468143C2065BBBC78149f1FcAF1",
        service: "0x4C0301d076D90468143C2065BBBC78149f1FcAF1",
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
