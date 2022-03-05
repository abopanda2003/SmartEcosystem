// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface ISmartFarm {
    /// @dev Pool Information
    struct PoolInfo {
        address stakingTokenAddress;     // staking contract address
        address rewardTokenAddress;      // reward token contract
        uint256 rewardPerDay;            // reward percent per day
        uint unstakingFee;            
        uint256 totalStaked;             /* How many tokens we have successfully staked */
    }

    struct UserInfo {
        uint256 balance;
        uint256 rewards;
        uint256 rewardPerTokenPaid;     // User rewards per token paid for passive
        uint256 lastUpdated;
    }
    
    function stakeSMT(address account, uint256 amount) external returns(uint256);
    function withdrawSMT(address account, uint256 amount) external returns(uint256);
    function claimReward() external;
    function notifyRewardAmount(uint _reward) external;
}
