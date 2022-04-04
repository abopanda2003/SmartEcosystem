// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import '../libs/IBEP20.sol';

interface ISmartTokenCash is IBEP20 {
    function burn(uint256 amount) external; 
}
