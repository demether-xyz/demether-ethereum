const { network } = require("hardhat");
const { deployer, getDependencies, dependenciesDeployer } = require("./deployer");

function getSettings(network) {
  switch (network) {
    case "sepolia":
      return {
        owner: "0x4C0301d076D90468143C2065BBBC78149f1FcAF1",
        service: "0x4C0301d076D90468143C2065BBBC78149f1FcAF1",
      };
    case "mainnet":
      return {
        owner: "0x4C0301d076D90468143C2065BBBC78149f1FcAF1",
        service: "0x4C0301d076D90468143C2065BBBC78149f1FcAF1",
      };
  }
}

async function main() {
  const list = [];
  let dependencies = await getDependencies(list, network.name);
  const settings = getSettings(network.name);

  await dependenciesDeployer({
    name: "deposits_manager_L1",
    params: {
      name: "DepositsManagerL1",
      isProxy: true,
      params: [settings.owner, settings.service],
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
