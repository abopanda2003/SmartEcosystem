// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import './ISmartArmy.sol';
import './ISmartLadder.sol';
import './ISmartFarm.sol';
import './IGoldenTreePool.sol';
import './ISmartNobilityAchievement.sol';
import './ISmartOtherAchievement.sol';
import './IUniswapRouter.sol';
import "./ISmartTokenCash.sol";

// Smart Comptroller Interface
interface ISmartComp {
    function isComptroller() external pure returns(bool);
    function getSMT() external view returns(IERC20);
    function getBUSD() external view returns(IERC20);
    function getWBNB() external view returns(IERC20);

    function getSMTC() external view returns(ISmartTokenCash);
    function getUniswapV2Router() external view returns(IUniswapV2Router02);
    function getUniswapV2Factory() external view returns(address);
    function getSmartArmy() external view returns(ISmartArmy);
    function getSmartLadder() external view returns(ISmartLadder);
    function getSmartFarm() external view returns(ISmartFarm);
    function getGoldenTreePool() external view returns(IGoldenTreePool);
    function getSmartNobilityAchievement() external view returns(ISmartNobilityAchievement);
    function getSmartOtherAchievement() external view returns(ISmartOtherAchievement);
    function getSmartBridge() external view returns(address);
}
