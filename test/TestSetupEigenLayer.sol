// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC20PresetFixedSupply, IERC20 } from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IBeacon } from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import { DelegationManager } from "@eigenlayer/contracts/core/DelegationManager.sol";

import { IETHPOSDeposit } from "@eigenlayer/contracts/interfaces/IETHPOSDeposit.sol";

import { StrategyManager } from "@eigenlayer/contracts/core/StrategyManager.sol";
import { StrategyBase } from "@eigenlayer/contracts/strategies/StrategyBase.sol";
import { IStrategy } from "@eigenlayer/contracts/interfaces/IStrategy.sol";

import { Slasher } from "@eigenlayer/contracts/core/Slasher.sol";

import { EigenPod, IEigenPod } from "@eigenlayer/contracts/pods/EigenPod.sol";
import { EigenPodManager } from "@eigenlayer/contracts/pods/EigenPodManager.sol";
import {
    DelayedWithdrawalRouter,
    IDelayedWithdrawalRouter
} from "@eigenlayer/contracts/pods/DelayedWithdrawalRouter.sol";

import { PauserRegistry } from "@eigenlayer/contracts/permissions/PauserRegistry.sol";
import { ETHPOSDepositMock } from "@eigenlayer/test/mocks/ETHDepositMock.sol";

import { EmptyContract } from "@eigenlayer/test/mocks/EmptyContract.sol";
import { BeaconChainOracleMock } from "@eigenlayer/test/mocks/BeaconChainOracleMock.sol";

import { Test, stdJson } from "forge-std/Test.sol";

contract TestSetupEigenLayer is Test, ETHPOSDepositMock {
    //Vm cheats = Vm(HEVM_ADDRESS);

    // EigenLayer contracts
    struct EigenLayerContracts {
        ProxyAdmin eigenLayerProxyAdmin;
        PauserRegistry eigenLayerPauserReg;
        Slasher slasher;
        DelegationManager delegation;
        StrategyManager strategyManager;
        EigenPodManager eigenPodManager;
        IEigenPod pod;
        IDelayedWithdrawalRouter delayedWithdrawalRouter;
        IETHPOSDeposit ethPOSDeposit;
        IBeacon eigenPodBeacon;
    }
    EigenLayerContracts public eigenLayerContracts;

    // testing/mock contracts
    struct MockContracts {
        IERC20 eigenToken;
        IERC20 weth;
        StrategyBase wethStrat;
        StrategyBase eigenStrat;
        StrategyBase baseStrategyImplementation;
        EmptyContract emptyContract;
    }
    MockContracts public mockContracts;

    // Other Addresses
    struct Addresses {
        address[2] stakers;
        address pauser;
        address unpauser;
        //sk: e88d9d864d5d731226020c5d2f02b62a4ce2a4534a39c225d32d3db795f83319
        address acct0;
        address acct1;
        address eigenLayerProxyAdminAddress;
        address eigenLayerPauserRegAddress;
        address slasherAddress;
        address delegationAddress;
        address strategyManagerAddress;
        address eigenPodManagerAddress;
        // address podAddress;
        address delayedWithdrawalRouterAddress;
        // address eigenPodBeaconAddress;
        address beaconChainOracleAddress;
        address emptyContractAddress;
        address operationsMultisig;
        address executorMultisig;
    }
    Addresses internal addresses;

    mapping(uint256 number => IStrategy strat) public strategies;

    //strategy indexes for undelegation (see commitUndelegation function)
    // uint256[] public strategyIndexes;
    //    address sample_registrant = Vm.addr(436364636);

    // address[] public slashingContracts;

    uint256 public constant WRTH_INITIAL_SUPPLY = 10e50;
    // uint256 public constant EIGEN_TOTAL_SUPPLY = 1000e18;
    // uint256 public constant NONCE = 69;
    // uint256 public constant GAS_LIMIT = 750000;

    //from testing seed phrase
    bytes32 public constant PRIV_KEY_0 = 0x1234567812345678123456781234567812345678123456781234567812345678;
    bytes32 public constant PRIV_KEY_1 = 0x1234567812345678123456781234567812345698123456781234567812348976;
    IStrategy[] public initializeStrategiesToSetDelayBlocks;
    uint256[] public initializeWithdrawalDelayBlocks;
    uint256 public constant MIN_WITHDRAWAL_DELAY_BLOCKS = 0;
    // uint32 public constant ARTIAL_WITHDRAWAL_FRAUD_PROOF_PERIOD_BLOCKS = 7 days / 12 seconds;
    // uint256 public constant REQUIRED_BALANCE_WEI = 32 ether;
    // uint64 public constant MAX_PARTIAL_WTIHDRAWAL_AMOUNT_GWEI = 1 ether / 1e9;
    uint64 public constant MAX_RESTAKED_BALANCE_GWEI_PER_VALIDATOR = 32e9;
    uint64 public constant GOERLI_GENESIS_TIME = 1616508000;
    // address public constant THE_MULTI_SIG = address(420);
    address public constant OPERATOR = address(0x4206904396bF2f8b173350ADdEc5007A52664293);
    // address public constant CHALLENGER = address(0x6966904396bF2f8b173350bCcec5007A52669873);
    uint256 public constant INITIAL_BEACON_CHAIN_ORACLE_THRESHOLD = 3;
    uint32 public constant PARTIAL_WITHDRAWAL_FRAUD_PROOF_PERIOD_BLOCKS = 7 days / 12 seconds;
    address public EIGEN_LAYER_REPUTED_MULTISIG = address(this);

    string internal goerliDeploymentConfig;
    // = vm.readFile("script/output/goerli/M1_deployment_goerli_2023_3_23.json");

    // addresses excluded from fuzzing due to abnormal behavior
    // TODO: @Sidu28 define this better and give it a clearer name
    mapping(address addr => bool fuzzed) public fuzzedAddressMapping;

    //ensures that a passed in address is not set to true in the fuzzedAddressMapping
    //    modifier fuzzedAddress(address addr) virtual {
    //        cheats.assume(fuzzedAddressMapping[addr] == false);
    //        _;
    //    }

    //    modifier cannotReinit() {
    //        cheats.expectRevert(bytes("Initializable: contract is already initialized"));
    //        _;
    //    }

    //performs basic deployment before each test
    // for fork tests run:  forge test -vv --fork-url https://eth-goerli.g.alchemy.com/v2/demo   -vv
    function setUp() public virtual {
        addresses.acct0 = vm.addr(uint256(PRIV_KEY_0));
        addresses.acct1 = vm.addr(uint256(PRIV_KEY_1));
        //        try Vm.envUint("CHAIN_ID") returns (uint256 chainId) {
        //            if (chainId == 31337) {
        //                _deployEigenLayerContractsLocal();
        //            } else if (chainId == 5) {
        //                _deployEigenLayerContractsGoerli();
        //            }
        //            // If CHAIN_ID ENV is not set, assume local deployment on 31337
        //        } catch {
        //            _deployEigenLayerContractsLocal();
        //        }
        _deployEigenLayerContractsLocal();

        fuzzedAddressMapping[address(0)] = true;
        fuzzedAddressMapping[address(eigenLayerContracts.eigenLayerProxyAdmin)] = true;
        fuzzedAddressMapping[address(eigenLayerContracts.strategyManager)] = true;
        fuzzedAddressMapping[address(eigenLayerContracts.eigenPodManager)] = true;
        fuzzedAddressMapping[address(eigenLayerContracts.delegation)] = true;
        fuzzedAddressMapping[address(eigenLayerContracts.slasher)] = true;
    }

    function _deployEigenLayerContractsGoerli() internal {
        _setAddresses(goerliDeploymentConfig);
        addresses.pauser = addresses.operationsMultisig;
        addresses.unpauser = addresses.executorMultisig;
        // deploy proxy admin for ability to upgrade proxy contracts
        eigenLayerContracts.eigenLayerProxyAdmin = ProxyAdmin(addresses.eigenLayerProxyAdminAddress);

        mockContracts.emptyContract = new EmptyContract();

        //deploy addresses.pauser registry
        eigenLayerContracts.eigenLayerPauserReg = PauserRegistry(addresses.eigenLayerPauserRegAddress);

        eigenLayerContracts.delegation = DelegationManager(addresses.delegationAddress);
        eigenLayerContracts.strategyManager = StrategyManager(addresses.strategyManagerAddress);
        eigenLayerContracts.slasher = Slasher(addresses.slasherAddress);
        eigenLayerContracts.eigenPodManager = EigenPodManager(addresses.eigenPodManagerAddress);
        eigenLayerContracts.delayedWithdrawalRouter = DelayedWithdrawalRouter(addresses.delayedWithdrawalRouterAddress);

        addresses.beaconChainOracleAddress = address(new BeaconChainOracleMock());

        eigenLayerContracts.ethPOSDeposit = new ETHPOSDepositMock();
        eigenLayerContracts.pod = new EigenPod(
            eigenLayerContracts.ethPOSDeposit,
            eigenLayerContracts.delayedWithdrawalRouter,
            eigenLayerContracts.eigenPodManager,
            MAX_RESTAKED_BALANCE_GWEI_PER_VALIDATOR,
            GOERLI_GENESIS_TIME
        );

        eigenLayerContracts.eigenPodBeacon = new UpgradeableBeacon(address(eigenLayerContracts.pod));

        //simple ERC20 (**NOT** WETH-like!), used in a test strategy
        mockContracts.weth = new ERC20PresetFixedSupply(
            "mockContracts.weth",
            "WETH",
            WRTH_INITIAL_SUPPLY,
            address(this)
        );

        // deploy StrategyBase contract implementation, then create
        // upgradeable proxy that points to implementation and initialize it
        mockContracts.baseStrategyImplementation = new StrategyBase(eigenLayerContracts.strategyManager);
        mockContracts.wethStrat = StrategyBase(
            address(
                new TransparentUpgradeableProxy(
                    address(mockContracts.baseStrategyImplementation),
                    address(eigenLayerContracts.eigenLayerProxyAdmin),
                    abi.encodeWithSelector(
                        StrategyBase.initialize.selector,
                        mockContracts.weth,
                        eigenLayerContracts.eigenLayerPauserReg
                    )
                )
            )
        );

        mockContracts.eigenToken = new ERC20PresetFixedSupply("eigen", "EIGEN", WRTH_INITIAL_SUPPLY, address(this));

        // deploy upgradeable proxy that points to
        // StrategyBaseimplementation and initialize it
        mockContracts.eigenStrat = StrategyBase(
            address(
                new TransparentUpgradeableProxy(
                    address(mockContracts.baseStrategyImplementation),
                    address(eigenLayerContracts.eigenLayerProxyAdmin),
                    abi.encodeWithSelector(
                        StrategyBase.initialize.selector,
                        mockContracts.eigenToken,
                        eigenLayerContracts.eigenLayerPauserReg
                    )
                )
            )
        );

        addresses.stakers = [addresses.acct0, addresses.acct1];
    }

    function _deployEigenLayerContractsLocal() internal {
        addresses.pauser = address(69);
        addresses.unpauser = address(489);
        // deploy proxy admin for ability to upgrade proxy contracts
        eigenLayerContracts.eigenLayerProxyAdmin = new ProxyAdmin();

        //deploy addresses.pauser registry
        address[] memory pausers = new address[](1);
        pausers[0] = addresses.pauser;
        eigenLayerContracts.eigenLayerPauserReg = new PauserRegistry(pausers, addresses.unpauser);

        /**
         * First, deploy upgradeable proxy contracts that **will point**
         * to the implementations. Since the implementation contracts are
         * not yet deployed, we give these proxies an empty contract as the
         * initial implementation, to act as if they have no code.
         */
        mockContracts.emptyContract = new EmptyContract();
        eigenLayerContracts.delegation = DelegationManager(
            address(
                new TransparentUpgradeableProxy(
                    address(mockContracts.emptyContract),
                    address(eigenLayerContracts.eigenLayerProxyAdmin),
                    ""
                )
            )
        );
        eigenLayerContracts.strategyManager = StrategyManager(
            address(
                new TransparentUpgradeableProxy(
                    address(mockContracts.emptyContract),
                    address(eigenLayerContracts.eigenLayerProxyAdmin),
                    ""
                )
            )
        );
        eigenLayerContracts.slasher = Slasher(
            address(
                new TransparentUpgradeableProxy(
                    address(mockContracts.emptyContract),
                    address(eigenLayerContracts.eigenLayerProxyAdmin),
                    ""
                )
            )
        );
        eigenLayerContracts.eigenPodManager = EigenPodManager(
            address(
                new TransparentUpgradeableProxy(
                    address(mockContracts.emptyContract),
                    address(eigenLayerContracts.eigenLayerProxyAdmin),
                    ""
                )
            )
        );
        eigenLayerContracts.delayedWithdrawalRouter = DelayedWithdrawalRouter(
            address(
                new TransparentUpgradeableProxy(
                    address(mockContracts.emptyContract),
                    address(eigenLayerContracts.eigenLayerProxyAdmin),
                    ""
                )
            )
        );

        eigenLayerContracts.ethPOSDeposit = new ETHPOSDepositMock();
        eigenLayerContracts.pod = new EigenPod(
            eigenLayerContracts.ethPOSDeposit,
            eigenLayerContracts.delayedWithdrawalRouter,
            eigenLayerContracts.eigenPodManager,
            MAX_RESTAKED_BALANCE_GWEI_PER_VALIDATOR,
            GOERLI_GENESIS_TIME
        );

        eigenLayerContracts.eigenPodBeacon = new UpgradeableBeacon(address(eigenLayerContracts.pod));

        // Second, deploy the *implementation* contracts, using the *proxy contracts* as inputs
        DelegationManager delegationImplementation = new DelegationManager(
            eigenLayerContracts.strategyManager,
            eigenLayerContracts.slasher,
            eigenLayerContracts.eigenPodManager
        );
        StrategyManager strategyManagerImplementation = new StrategyManager(
            eigenLayerContracts.delegation,
            eigenLayerContracts.eigenPodManager,
            eigenLayerContracts.slasher
        );
        Slasher slasherImplementation = new Slasher(
            eigenLayerContracts.strategyManager,
            eigenLayerContracts.delegation
        );
        EigenPodManager eigenPodManagerImplementation = new EigenPodManager(
            eigenLayerContracts.ethPOSDeposit,
            eigenLayerContracts.eigenPodBeacon,
            eigenLayerContracts.strategyManager,
            eigenLayerContracts.slasher,
            eigenLayerContracts.delegation
        );
        DelayedWithdrawalRouter delayedWithdrawalRouterImplementation = new DelayedWithdrawalRouter(
            eigenLayerContracts.eigenPodManager
        );

        // Third, upgrade the proxy contracts to use the correct implementation contracts and initialize them.
        eigenLayerContracts.eigenLayerProxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(eigenLayerContracts.delegation))),
            address(delegationImplementation),
            abi.encodeWithSelector(
                DelegationManager.initialize.selector,
                EIGEN_LAYER_REPUTED_MULTISIG,
                eigenLayerContracts.eigenLayerPauserReg,
                0 /*initialPausedStatus*/,
                MIN_WITHDRAWAL_DELAY_BLOCKS,
                initializeStrategiesToSetDelayBlocks,
                initializeWithdrawalDelayBlocks
            )
        );
        eigenLayerContracts.eigenLayerProxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(eigenLayerContracts.strategyManager))),
            address(strategyManagerImplementation),
            abi.encodeWithSelector(
                StrategyManager.initialize.selector,
                EIGEN_LAYER_REPUTED_MULTISIG,
                EIGEN_LAYER_REPUTED_MULTISIG,
                eigenLayerContracts.eigenLayerPauserReg,
                0 /*initialPausedStatus*/
            )
        );
        eigenLayerContracts.eigenLayerProxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(eigenLayerContracts.slasher))),
            address(slasherImplementation),
            abi.encodeWithSelector(
                Slasher.initialize.selector,
                EIGEN_LAYER_REPUTED_MULTISIG,
                eigenLayerContracts.eigenLayerPauserReg,
                0 /*initialPausedStatus*/
            )
        );
        eigenLayerContracts.eigenLayerProxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(eigenLayerContracts.eigenPodManager))),
            address(eigenPodManagerImplementation),
            abi.encodeWithSelector(
                EigenPodManager.initialize.selector,
                addresses.beaconChainOracleAddress,
                EIGEN_LAYER_REPUTED_MULTISIG,
                eigenLayerContracts.eigenLayerPauserReg,
                0 /*initialPausedStatus*/
            )
        );
        uint256 initPausedStatus = 0;
        uint256 withdrawalDelayBlocks = PARTIAL_WITHDRAWAL_FRAUD_PROOF_PERIOD_BLOCKS;
        eigenLayerContracts.eigenLayerProxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(eigenLayerContracts.delayedWithdrawalRouter))),
            address(delayedWithdrawalRouterImplementation),
            abi.encodeWithSelector(
                DelayedWithdrawalRouter.initialize.selector,
                EIGEN_LAYER_REPUTED_MULTISIG,
                eigenLayerContracts.eigenLayerPauserReg,
                initPausedStatus,
                withdrawalDelayBlocks
            )
        );

        //simple ERC20 (**NOT** WETH-like!), used in a test strategy
        mockContracts.weth = new ERC20PresetFixedSupply(
            "mockContracts.weth",
            "WETH",
            WRTH_INITIAL_SUPPLY,
            address(this)
        );

        // deploy StrategyBase contract implementation, then create
        // upgradeable proxy that points to implementation and initialize it
        mockContracts.baseStrategyImplementation = new StrategyBase(eigenLayerContracts.strategyManager);
        mockContracts.wethStrat = StrategyBase(
            address(
                new TransparentUpgradeableProxy(
                    address(mockContracts.baseStrategyImplementation),
                    address(eigenLayerContracts.eigenLayerProxyAdmin),
                    abi.encodeWithSelector(
                        StrategyBase.initialize.selector,
                        mockContracts.weth,
                        eigenLayerContracts.eigenLayerPauserReg
                    )
                )
            )
        );

        mockContracts.eigenToken = new ERC20PresetFixedSupply("eigen", "EIGEN", WRTH_INITIAL_SUPPLY, address(this));

        // deploy upgradeable proxy that points to StrategyBase implementation and initialize it
        mockContracts.eigenStrat = StrategyBase(
            address(
                new TransparentUpgradeableProxy(
                    address(mockContracts.baseStrategyImplementation),
                    address(eigenLayerContracts.eigenLayerProxyAdmin),
                    abi.encodeWithSelector(
                        StrategyBase.initialize.selector,
                        mockContracts.eigenToken,
                        eigenLayerContracts.eigenLayerPauserReg
                    )
                )
            )
        );

        addresses.stakers = [addresses.acct0, addresses.acct1];
    }

    function _setAddresses(string memory config) internal {
        addresses.eigenLayerProxyAdminAddress = stdJson.readAddress(
            config,
            ".addresses.eigenLayerContracts.eigenLayerProxyAdmin"
        );
        addresses.eigenLayerPauserRegAddress = stdJson.readAddress(
            config,
            ".addresses.eigenLayerContracts.eigenLayerPauserReg"
        );
        addresses.delegationAddress = stdJson.readAddress(config, ".addresses.eigenLayerContracts.delegation");
        addresses.strategyManagerAddress = stdJson.readAddress(
            config,
            ".addresses.eigenLayerContracts.strategyManager"
        );
        addresses.slasherAddress = stdJson.readAddress(config, ".addresses.eigenLayerContracts.slasher");
        addresses.eigenPodManagerAddress = stdJson.readAddress(
            config,
            ".addresses.eigenLayerContracts.eigenPodManager"
        );
        addresses.delayedWithdrawalRouterAddress = stdJson.readAddress(
            config,
            ".addresses.eigenLayerContracts.delayedWithdrawalRouter"
        );
        addresses.emptyContractAddress = stdJson.readAddress(config, ".addresses.mockContracts.emptyContract");
        addresses.operationsMultisig = stdJson.readAddress(config, ".parameters.addresses.operationsMultisig");
        addresses.executorMultisig = stdJson.readAddress(config, ".parameters.addresses.executorMultisig");
    }
}
