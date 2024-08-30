// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Script, console } from "forge-std/Script.sol";
import { LiquidityPool } from "../../src/LiquidityPool.sol";

contract LiquidityPoolConfigScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address liquidityPoolAddress = vm.envAddress("LIQUIDITY_POOL_L2");

        uint256 protocolFee = 1e16; // 1% fee (in 1e18 precision, adjust as needed)
        address symbioticAddress = "";
        address eigenLayerStrategyManager = "";
        address eigenLayerStrategy = "";
        address eigenLayerDelegationManager = "";
        address curvePoolAddress = "";
        address protocolTreasury = "";
        uint8 strategy = 0; // STRATEGY_EIGENLAYER or STRATEGY_SYMBIOTIC, set as needed (0 for EigenLayer, 1 for Symbiotic)
        address fraxMinterAddress = "";

        LiquidityPool liquidityPool = LiquidityPool(liquidityPoolAddress);

        liquidityPool.setProtocolFee(protocolFee);
        console.log("setProtocolFee called with:", protocolFee);

        liquidityPool.setSymbiotic(symbioticAddress);
        console.log("setSymbiotic called with:", symbioticAddress);

        liquidityPool.setEigenLayer(eigenLayerStrategyManager, eigenLayerStrategy, eigenLayerDelegationManager);
        console.log("setEigenLayer called with strategy manager:", eigenLayerStrategyManager);
        console.log("setEigenLayer called with strategy:", eigenLayerStrategy);
        console.log("setEigenLayer called with delegation manager:", eigenLayerDelegationManager);

        liquidityPool.setCurvePool(curvePoolAddress);
        console.log("setCurvePool called with:", curvePoolAddress);

        liquidityPool.setProtocolTreasury(protocolTreasury);
        console.log("setProtocolTreasury called with:", protocolTreasury);

        liquidityPool.setStrategy(strategy);
        console.log("setStrategy called with:", strategy);

        liquidityPool.setFraxMinter(fraxMinterAddress);
        console.log("setFraxMinter called with:", fraxMinterAddress);

        vm.stopBroadcast();
    }
}
