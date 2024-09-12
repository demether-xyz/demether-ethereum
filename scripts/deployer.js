const { ethers, upgrades, network, defender } = require("hardhat");
const debug = require("debug")("deployment");
const fs = require("fs/promises");

const deployer = async function ({ name, params, isProxy = true, options })
{
  // const signer = ethers.Wallet.fromMnemonic(process.env.MNEMONIC).connect(provider);
  let owner;
  [owner] = await ethers.getSigners();
  owner.estimateGas = 4e6;
  const Contract = await ethers.getContractFactory(name, owner);
  let contract;
  if (isProxy) {
    contract = await upgrades.deployProxy(Contract, params, options);
  } else {
    contract = params ? await Contract.deploy(...params) : await Contract.deploy();
  }
  await contract.waitForDeployment();
  debug(name, contract.target);
  return contract;
};

const upgrader = async function ({ name, address }) {
  const Contract = await ethers.getContractFactory(name);
  const contract = await upgrades.upgradeProxy(address, Contract, { timeout: 60_000 * 30 });
  debug(name, "upgraded");
  return contract;
};

const importContract = async function ({ name, address }) {
  const Contract = await ethers.getContractFactory(name);
  await upgrades.forceImport(address, Contract, { kind: "uups" });
};

const proposeUpgrade = async function ({ name, address }) {
  const Main = await ethers.getContractFactory(name);
  const proposal = await defender.proposeUpgradeWithApproval(address, Main);
  debug(name, "Upgrade proposal created at:", proposal.url);
  return { address };
};

async function dependenciesDeployer({ token, name, params = {}, deployerFunction, dependencies }) {
  const [deployer] = await ethers.getSigners();

  // Deploy
  debug("Started:", name);
  let contract = await deployerFunction({ ...params, deployer });
  let dependencies_ = dependencies;
  let address = contract.target;

  // Save address
  await saveContract({
    token,
    name,
    dependencies: dependencies_,
    deployer: deployer.address,
    address,
    implementation: contract.implementation,
  });

  return contract;
}

async function saveContract({ token, name, dependencies, address, deployer, implementation }) {
  let proxyAdmin = null;
  try {
    proxyAdmin = await upgrades.admin.getInstance();
  } catch {}

  // Save address
  const tokenName = token ? { token } : {};
  const output = {
    ...tokenName,
    name,
    address: address,
    proxyAdmin: proxyAdmin?.address,
    implementation,
    dependencies,
    deployer: deployer,
    date: new Date(),
  };
  let deploymentString = JSON.stringify(output, null, 4);
  const tokenPath = token ? `${token}/` : "";

  // Check path exists
  if (token) {
    const dir = `deployment/${tokenPath}`;
    try {
      await fs.access(dir);
    } catch {
      await fs.mkdir(dir);
    }
  }

  await fs.writeFile(`deployment/${tokenPath}${network.name}.${name}.json`, deploymentString);
}

async function getDependencies(dependencies, network = "local", token = null) {
  let output = {};
  for (const i in dependencies) {
    const name = dependencies[i];

    // Check if token related
    const tokenPath = token ? `${token}/` : "";
    const addressesFile = `deployment/${tokenPath}${network}.${name}.json`;
    try {
      const addressJson = await fs.readFile(addressesFile);
      const info = JSON.parse(addressJson.toString());
      output = {
        ...info.dependencies,
        ...output,
        [name]: info.address,
      };
    } catch {
      debug(`${addressesFile}: You need to deploy your contract first`);
    }
  }
  return output;
}

module.exports = { deployer, upgrader, proposeUpgrade, dependenciesDeployer, getDependencies, importContract };
