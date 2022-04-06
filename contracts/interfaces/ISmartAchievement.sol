// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface ISmartAchievement {

    struct NobilityType {
        string            title;               // Title of Nobility Folks Baron Count Viscount Earl Duke Prince King
        uint256           growthRequried;      // Required growth token
        uint256           goldenTreeRewards;   // SMTC golden tree rewards
        uint256           passiveShare;        // Passive share percent
        uint256           availableTitles;     // Titles available
        uint256[]         chestSMTRewardPool;
        uint256[]         chestSMTCRewardPool;        
    }

    struct UserInfo {
        uint256[] chestRewards; // 0: SMT,  1: SMTC
        uint256 checkRewardUpdated;
        uint256[] surprizeRewards; // 0: SMT, 1: SMTC
        uint256[] nobleRewards; // 0: claim, 1: unclaim       
        uint256[] farmRewards;  // 0: claim, 1: unclaim
        uint256[] sellTaxRewards;  // 0: claim, 1: unclaim
        uint256[] passiveShareRewards; // 0: claim, 1: unclaim
    }

    function addFarmDistributor(address) external;

    function claimNobleReward(uint256) external;
    function claimFarmReward(uint256) external;
    function claimChestSMTReward(uint256) external;
    function claimChestSMTCReward(uint256) external;
    function claimSurprizeSMTReward(uint256) external;
    function claimSurprizeSMTCReward(uint256) external;
    function claimSellTaxReward(uint256) external;
    function claimPassiveShareReward(uint256) external;

    function distributeSellTax(uint256) external;
    function distributeToNobleLeaders(uint256) external;
    function distributeToFarmers(uint256) external;
    function distributeSurprizeReward(address, uint256) external;

    function notifyGrowth(address, uint256, uint256) external returns(bool);
    function removeFarmDistributor(address) external;
    function swapDistribute(uint256) external;

    function isNobleLeader(address) external view returns(bool);
    function isFarmer(address) external view returns(bool);
    function isUpgradeable(uint256, uint256) external view returns(bool, uint256);

    function nobilityOf(address) external view returns(NobilityType memory);
    function nobilityTitleOf(address) external view returns(string memory);
}