// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface ISmartAchievement {

    struct NobilityType {
        string            title;               // Title of Nobility Folks Baron Count Viscount Earl Duke Prince King
        uint256           growthRequried;      // Required growth token
        uint256           goldenTreeRewards;   // SMTC golden tree rewards
        uint256           passiveShare;        // Passive share percent
        uint256           availableTitles;     // Titles available
        uint256[]         chestSMTRewards;
        uint256[]         chestSMTCRewards;
    }

    function addFarmDistributor(address) external;
    function claimReward() external;
    function claimChestReward() external;
    function claimNobleReward(uint256) external;
    function claimFarmReward(uint256) external;
    function claimSurprizeSMTReward(uint256) external;
    function claimSurprizeSMTCReward(uint256) external;
    function distributeToNobleLeaders(uint256) external;
    function distributeToFarmers(uint256) external;
    function distributeSurprizeReward(address) external;
    function notifyGrowth(address account, uint256 oldGrowth, uint256 newGrowth) external returns(bool);
    function removeFarmDistributor(address) external;
    function swapDistribute() external;

    function isNobleLeader(address) external view returns(bool);
    function isFarmer(address) external view returns(bool);
    function isUpgradeable(uint256, uint256) external view returns(bool, uint256);
    function nobilityOf(address) external view returns(NobilityType memory);
    function nobilityTitleOf(address) external view returns(string memory);
}