// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IOFT, SendParam, MessagingFee } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

interface IDOFT is IERC20, IOFT {
    function mint(address _to, uint256 _amount) external returns (bool);
    function burn(address _from, uint256 _amount) external returns (bool);
}
