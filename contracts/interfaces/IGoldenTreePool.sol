// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IGoldenTreePool {
    function swapDistribute() external;
    function notifyReward(uint256 amount, address account) external;
}
