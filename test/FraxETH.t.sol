// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TestSetup.sol";

interface ICurveEMAOracle {
    function get_p() external view returns (uint256);
    function price_oracle() external view returns (uint256);
}

contract FraxETHTest is TestSetup {
    bool internal fork_active;
    ICurveEMAOracle public curveOracle;

    uint256 constant PRICE_PRECISION = 1e18;
    uint256 constant MIN_PRICE = 7e17; // 0.7 in 1e18 precision
    uint256 constant MAX_PRICE = 1e18; // 1 in 1e18 precision

    function setUp() public override {
        try vm.activeFork() {
            fork_active = true;
        } catch {}
        if (!fork_active) return;

        super.setUp();

        curveOracle = ICurveEMAOracle(0xa1F8A6807c402E4A15ef4EBa36528A3FED24E577);
    }

    function test_fork_frxETH_price() public {
        if (!fork_active) return;

        // Test spot price
        uint256 curvePrice = curveOracle.get_p();

        assertGe(curvePrice, MIN_PRICE, "Spot price should be >= 0.7");
        assertLe(curvePrice, MAX_PRICE, "Spot price should be <= 1");

        // Test oracle price
        uint256 oraclePrice = curveOracle.price_oracle();

        assertGe(oraclePrice, MIN_PRICE, "Oracle price should be >= 0.7");
        assertLe(oraclePrice, MAX_PRICE, "Oracle price should be <= 1");

        // Test price in ETH terms
        uint256 priceInEth = (PRICE_PRECISION * PRICE_PRECISION) / curvePrice;
        uint256 oraclePriceInEth = (PRICE_PRECISION * PRICE_PRECISION) / oraclePrice;

        assertGe(priceInEth, PRICE_PRECISION, "Price in ETH should be >= 1");
        assertLe(priceInEth, (PRICE_PRECISION * 10) / 7, "Price in ETH should be <= 1.428571");
        assertGe(oraclePriceInEth, PRICE_PRECISION, "Oracle price in ETH should be >= 1");
        assertLe(oraclePriceInEth, (PRICE_PRECISION * 10) / 7, "Oracle price in ETH should be <= 1.428571");
    }
}
