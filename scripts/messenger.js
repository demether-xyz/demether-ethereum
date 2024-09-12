const { network } = require("hardhat");
const { deployer, getDependencies, dependenciesDeployer } = require("./deployer");

function getSettings(network) {
  switch (network) {
    case "mainnet":
      return {
        weth: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
        service: "0x4C0301d076D90468143C2065BBBC78149f1FcAF1",
      };
    case "arbitrum":
      return {
        weth: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
        service: "0x4C0301d076D90468143C2065BBBC78149f1FcAF1",
      };
    case "sepolia":
      return {
        weth: "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14",
        service: "0x4C0301d076D90468143C2065BBBC78149f1FcAF1",
      };
  }
}

async function main() {
  const deposit_manager = ["mainnet", "sepolia"].includes(network.name) ? "deposits_manager_L1" : "deposits_manager_L2";
  const list = [deposit_manager, "timelock"];
  let dependencies = await getDependencies(list, network.name);
  const settings = getSettings(network.name);

  await dependenciesDeployer({
    name: "messenger",
    params: {
      name: "Messenger",
      isProxy: true,
      params: [settings.weth, dependencies[deposit_manager], settings.service, settings.service],
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
