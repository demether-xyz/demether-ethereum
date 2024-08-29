const { deployer, dependenciesDeployer } = require("./deployer");
const { network } = require("hardhat");

function getSettings(network) {
  switch (network) {
    case "arbitrum":
      return {
        proposers: ["0x0Fb539EEBE2ED7b69F0534FD01853F34C8A74254"],
        executors: [
          "0x0Fb539EEBE2ED7b69F0534FD01853F34C8A74254",
          "0x4C0301d076D90468143C2065BBBC78149f1FcAF1",
          "0x8974E27d6f0CeC47ED4c6469cc5e81562A4292b9",
          "0x2C871ad626E775092F1762a884F582a74B97b29B",
        ],
      };
  }
}
async function main() {
  const settings = getSettings(network.name);
  await dependenciesDeployer({
    name: "timelock",
    params: {
      name: "TimeLock",
      isProxy: false,
      params: [
        1, // initial 1 second for set-up
        settings.proposers,
        settings.executors,
        "0x0000000000000000000000000000000000000000",
      ],
    },
    deployerFunction: deployer,
    dependencies: [],
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
