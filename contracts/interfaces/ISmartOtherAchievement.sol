// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface ISmartOtherAchievement {

    struct UserInfo {
        uint256[] surprizeRewards; // 0: SMT, 1: SMTC
        uint256[] farmRewards;  // 0: claim, 1: unclaim
        uint256[] sellTaxRewards;  // 0: claim, 1: unclaim
    }

    function claimFarmReward(uint256) external;
    function claimSurprizeSMTReward(uint256) external;
    function claimSurprizeSMTCReward(uint256) external;
    function claimSellTaxReward(uint256) external;

    function distributeSellTax(uint256) external;
    function distributeToFarmers(uint256) external;
    function distributeSurprizeReward(address, uint256) external;

    function addFarmDistributor(address) external;
    function removeFarmDistributor(address) external;

    function swapDistribute(uint256) external;

    function isFarmer(address) external view returns(bool);

}