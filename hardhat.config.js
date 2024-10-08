require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-foundry");
require("@openzeppelin/hardhat-upgrades");
require("@nomicfoundation/hardhat-verify");

const MNEMONIC = process.env.MNEMONIC || "test test test test test test test test test test test junk";

const chainIds = {
  mainnet: 1,
  arbitrum: 42161,
  sepolia: 11155111,
  morph_holesky: 2810,
  celo_alfajores: 44787,
  celo: 42220,
};

function createTestnetConfig(network) {
  switch (network) {
    case "mainnet":
      url = "https://eth-mainnet.g.alchemy.com/v2/ESrlxBQxB17StnQQKuXeV8V1o4G5aLuW";
      break;
    case "sepolia":
      url = "https://eth-sepolia.g.alchemy.com/v2/ESrlxBQxB17StnQQKuXeV8V1o4G5aLuW";
      break;
    case "arbitrum":
      url = "https://arb-mainnet.g.alchemy.com/v2/ESrlxBQxB17StnQQKuXeV8V1o4G5aLuW";
      break;
    case "celo":
      url = "https://celo-mainnet.infura.io/v3/99b4edc128834c78b4d9a46d6369e3aa";
      break;
    case "celo_alfajores":
      url = "https://alfajores-forno.celo-testnet.org";
      break;
    case "morph_holesky":
      url = "https://blissful-late-tent.morph-holesky.quiknode.pro/cde3ea40627ca03856d86b56c7174d515a95fe92";
      break;
  }

  return {
    accounts: {
      count: 20,
      initialIndex: 0,
      mnemonic: MNEMONIC,
      path: "m/44'/60'/0'/0",
    },
    chainId: chainIds[network],
    url,
    timeout: 60000,
  };
}

module.exports = {
  networks: {
    local: {
      url: "http://127.0.0.1:8545/",
      accounts: {
        count: 20,
        initialIndex: 0,
        mnemonic: MNEMONIC,
        path: "m/44'/60'/0'/0",
      },
      chainId: 1,
      timeout: 60_000 * 30,
    },
    mainnet: createTestnetConfig("mainnet"),
    arbitrum: createTestnetConfig("arbitrum"),
    sepolia: createTestnetConfig("sepolia"),
    morph_holesky: createTestnetConfig("morph_holesky"),
    celo_alfajores: createTestnetConfig("celo_alfajores"),
    celo: createTestnetConfig("celo"),
  },
  solidity: {
    version: "0.8.26",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    sources: "./src", // Use ./src rather than ./contracts as Hardhat expects
    cache: "./cache_hardhat", // Use a different cache for Hardhat than Foundry
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN,
      arbitrumOne: process.env.ARBICAN,
      sepolia: process.env.ETHERSCAN,
    }
  },
  defender: {
    apiKey: process.env.DEFENDER_TEAM_API_KEY,
    apiSecret: process.env.DEFENDER_TEAM_API_SECRET_KEY,
  },
};
