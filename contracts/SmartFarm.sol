// SPDX-License-Identifier: MIT

/**
 * Smart Farming Contract
 * @author Liu
 */

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import './libs/TransferHelper.sol';

import './interfaces/ISmartComp.sol';
import './interfaces/IUniswapRouter.sol';
import './interfaces/IUniswapPair.sol';
import './interfaces/IUniswapFactory.sol';
import 'hardhat/console.sol';

contract SmartFarm is UUPSUpgradeable, OwnableUpgradeable, ISmartFarm {
  /// @dev Params for Passive Rewards
  uint public constant DURATION = 7 days;

  // Timestamp for current period finish
  uint256 public periodFinish;
  // RewardRate for the rest of the PERIOD
  uint256 public rewardRate;
  // Last time any user took action
  uint256 public lastUpdateTime;
  // Ever increasing rewardPerToken rate, based on % of total supply
  uint256 public rewardPerTokenStored;

  ISmartComp public comptroller;

  /// @dev Info of each user that stakes LP tokens.
  mapping(address => UserInfo) public userInfo;

  /// @dev Farming Tax percent to distribute
  uint256 public farmingTax_referral;
  uint256 public farmingTax_golden;
  uint256 public farmingTax_dev;
  uint256 public farmingTax_passive;
  uint256 public unstakingFee;

  uint256 public farmingRewardPercent;

  /// @dev Address for collecting fee
  address public feeAddress;

  uint256 public totalLpStaked;
  uint256 public totalStaked;

  event RewardAdded(uint256 reward);
  event Staked(address indexed account, uint256 amount, uint256 lp);
  event Withdrawn(address indexed account, uint256 amount, uint256 lp);
  event Claimed(address indexed account, uint256 amount);
  event UpdatedRewardWallet(address indexed account);

  function initialize(address _comp) 
    public initializer 
  {
		__Ownable_init();
    __SmartFarm_init_unchained(_comp);
  }

  function _authorizeUpgrade(address newImplementation) 
    internal override onlyOwner 
  {
  }

  function __SmartFarm_init_unchained(
    address _comp
  ) internal initializer {
    comptroller = ISmartComp(_comp);
    
    farmingTax_referral = 1000;
    farmingTax_golden = 300;
    farmingTax_dev = 100;
    farmingTax_passive = 100;

    unstakingFee = 0;
    farmingRewardPercent = 10;   // 0.1 %

    feeAddress = msg.sender;
  }

  /**
  * @notice Sets a new comptroller
  * @dev Admin function to set a new comptroller
  */
  function setComptroller(ISmartComp newComptroller) 
    external onlyOwner 
  {
    // Ensure invoke comptroller.isComptroller() returns true
    require(newComptroller.isComptroller(), "marker method returned false");
    // Set comptroller to newComptroller
    comptroller = newComptroller;
  }

  /**
   * Update Fee information
   */
  function updateFeeInfo(
    uint256 _farmingTax_referral,             // Farming tax percent for referral system
    uint256 _farmingTax_golden,               // Farming tax percent for golden tree pool
    uint256 _farmingTax_dev,                  // Farming tax percent for dev wallet
    uint256 _farmingTax_passive,              // Farming tax percent for passive share
    uint256 _unstakingFee,                    // Unstaking fee percent
    address _feeAddress
  ) external onlyOwner {
    require(_farmingTax_referral < 5000, "SmartFarm#updateFeeInfo: Too big farming tax referral");
    require(_farmingTax_golden < 5000, "SmartFarm#updateFeeInfo: Too big farming tax golden");
    require(_farmingTax_dev < 5000, "SmartFarm#updateFeeInfo: Too big farming tax dev");
    require(_farmingTax_passive < 5000, "SmartFarm#updateFeeInfo: Too big farming tax passwive");    
    require(_unstakingFee < 5000, "SmartFarm#updateFeeInfo: Too big unstaking fee");
    require(_feeAddress != address(0x0), "SmartFarm#updateFeeInfo: should be not zero address");
    
    farmingTax_referral = _farmingTax_referral;
    farmingTax_golden = _farmingTax_golden;
    farmingTax_dev = _farmingTax_dev;
    farmingTax_passive = _farmingTax_passive;
    unstakingFee = _unstakingFee;
    feeAddress = _feeAddress;
  }

  /**
   * Update farming reward pecentage and wallet address
   */
  function updateFarmingRewardParams(
    uint256 percent
  ) external onlyOwner {

    require(percent <= 10_000, "SmartFarm#updateFarmingReward: too big percent");
    farmingRewardPercent = percent;
  }

  /** @dev only Rewards distributors */
  modifier onlyRewardsDistributor() {
    require(
      msg.sender == (address)(comptroller.getSMT())
      || msg.sender == owner(), 
      "SmartFarm: only reward distributors"
    );
    _;
  }

  /**
   * @dev Notifies the contract that new rewards have been added.
   * Calculates an updated rewardRate based on the rewards in period.
   * @param _reward Units of RewardToken that have been added to the pool
   */
  function notifyRewardAmount(uint _reward)
    external override
    onlyRewardsDistributor
    updatePassiveReward(address(0), true)
  {
    uint currentTime = block.timestamp;

    // If previous period over, reset rewardRate
    if (currentTime >= periodFinish) {
      rewardRate = _reward / DURATION;
    }
    // If additional reward to existing period, calc sum
    else {
      uint remaining = periodFinish - currentTime;
      uint leftover = remaining * rewardRate;
      rewardRate = (_reward + leftover) / DURATION;
    }

    lastUpdateTime = currentTime;
    periodFinish = currentTime + DURATION;

    emit RewardAdded(_reward);
  }

  function calcPassiveReward(address account) internal {
    // Setting of global vars
    uint256 newRewardPerToken = rewardPerToken();
    // If statement protects against loss in initialisation case
    if (newRewardPerToken > 0) {
      rewardPerTokenStored = newRewardPerToken;
      lastUpdateTime = lastTimeRewardApplicable();
      // Setting of personal vars based on new globals
      if (account != address(0)) {
        UserInfo storage uInfo = userInfo[account];
        uInfo.rewards = earnedPassive(account);
        uInfo.rewardPerTokenPaid = newRewardPerToken;
      }
    }
  }

  /** @dev Updates the reward for a given address, before executing function */
  modifier updatePassiveReward(address account, bool beforeAndAfter) { // beforeAndAfter: 0: before,  1: after
    if(!beforeAndAfter) calcPassiveReward(account);
    _;
    if(beforeAndAfter) calcPassiveReward(account);
  }

  function calcFixedReward(address account) internal {
    if (account != address(0)) {
        UserInfo storage uInfo = userInfo[account];
        uInfo.rewards = earned(account);
        uInfo.lastUpdated = block.timestamp;
    }
  }

  modifier updateFixedReward(address account, bool beforeAndAfter) { // beforeAndAfter: 0: before,  1: after
      if(!beforeAndAfter) calcFixedReward(account);
      _;
      if(beforeAndAfter) calcFixedReward(account);
  }

  function reserveOf(address account) public view returns (uint256) {
    return userInfo[account].tokenBalance;
  }

  function balanceOf(address account) public view returns (uint256) {
    return userInfo[account].balance;
  }

  function rewardsOf(address account) public view returns (uint256) {
    return userInfo[account].rewards;
  }

  function havestOf(address account) public view returns (uint256) {
    return userInfo[account].havested;
  }

  function userInfoOf(address account) public view returns (UserInfo memory) {
    return userInfo[account];
  }

   /**
   * @dev Gets the last applicable timestamp for this reward period
   */
  function lastTimeRewardApplicable() public view returns (uint) {
    return block.timestamp < periodFinish? block.timestamp : periodFinish;
  }

  /**
   * @dev Calculates the amount of unclaimed rewards per token since last update,
   * and sums with stored to give the new cumulative reward per token
   * @return 'Reward' per staked token
   */
  function rewardPerToken() public view returns (uint) {
    // If there is no StakingToken liquidity, avoid div(0)
    uint256 stakedTokens = totalStaked;
    if (stakedTokens == 0) {
      return rewardPerTokenStored;
    }
    // new reward units to distribute = rewardRate * timeSinceLastUpdate
    uint256 rewardUnitsToDistribute = rewardRate * (lastTimeRewardApplicable() - lastUpdateTime);
    // prevent overflow
    require(rewardUnitsToDistribute < type(uint256).max / 1e18);
    // new reward units per token = (rewardUnitsToDistribute * 1e18) / totalTokens
    uint256 unitsToDistributePerToken = rewardUnitsToDistribute * 1e18 / stakedTokens;
    // return summed rate
    return rewardPerTokenStored + unitsToDistributePerToken;
  }

  /**
   * Calculate earned amount from lastUpdated to block.timestamp
   * Check License activate status while staking 
   */
  function earned(address account) public view returns (uint256) {
    uint256 blockTime = block.timestamp;
    UserInfo memory uInfo = userInfo[account];
    // Check license activation duration 
    (uint256 start, uint256 end) = comptroller.getSmartArmy().licenseActiveDuration(account, uInfo.lastUpdated, blockTime);
    if(start == 0 || end == 0) {
      return uInfo.rewards;
    }    
    uint256 duration = end - start;
    uint256 amount = duration * reserveOf(account) * farmingRewardPercent / 86400 / 10_000;
    return uInfo.rewards + amount;
  }

  /**
   * @dev Calculates the amount of unclaimed rewards a user has earned
   * @param _account User address
   * @return Total reward amount earned
   */
  function earnedPassive(address _account) public view returns (uint256) {
    UserInfo memory uInfo = userInfo[_account];

    // current rate per token - rate user previously received
    uint256 userRewardDelta = rewardPerToken() - uInfo.rewardPerTokenPaid;
    // new reward = staked tokens * difference in rate
    uint256 userNewReward = reserveOf(_account) * userRewardDelta / 1e18;
    // add to previous rewards
    return uInfo.rewards + userNewReward;
  }

  /**
   * Stake SMT token
   * Swap with BUSD and add liquidity to pcs
   * Lock LP token to contract
   */
  function stakeSMT(
    address account,
    uint256 amount    
  ) public override
    updateFixedReward(tx.origin, true)
    updatePassiveReward(tx.origin, true)
    returns(uint256)
  {
    ISmartArmy smartArmy = comptroller.getSmartArmy();
    require(_msgSender() == address(smartArmy) || _msgSender() == account, "SmartFarm#stakeSMT: invalid account");

    (uint256 liquidity, uint256 stakedAmount) = _tranferSmtToContract(account, amount);
    require(liquidity > 0, "SmartFarm#stakeSMT: failed to add liquidity");

    ISmartOtherAchievement ach = comptroller.getSmartOtherAchievement();
    if(stakedAmount > 100) ach.addFarmDistributor(tx.origin);

    UserInfo storage uInfo = userInfo[tx.origin];
    uInfo.balance = uInfo.balance + liquidity;
    uInfo.tokenBalance = uInfo.tokenBalance + stakedAmount;

    totalLpStaked = totalLpStaked + liquidity;
    totalStaked = totalStaked + stakedAmount;

    emit Staked(tx.origin, amount, liquidity);

    return liquidity;
  }

  /**
   * @notice Withdraw Staked SMT
   */
  function withdrawSMT(
    address account,
    uint256 lpAmount
  ) public override
    updateFixedReward(tx.origin, false)
    updatePassiveReward(tx.origin, false)
    returns(uint256)
  {
    require(lpAmount > 0, "SmartFarm#withdrawSMT: Cannot withdraw 0");
    require(lpAmount <= balanceOf(tx.origin), "SmartFarm#withdrawSMT: Cannot withdraw more than balance");

    ISmartArmy smartArmy = comptroller.getSmartArmy();
    uint256 lpLocked = smartArmy.lockedLPOf(tx.origin);

    require(_msgSender() == address(smartArmy) || _msgSender() == account, "SmartFarm#withdrawSMT: invalid account");

    if(_msgSender() == address(smartArmy)) {
      require(lpLocked == lpAmount, "SmartFarm#withdrawSMT: withdraw amount from SmartArmy is invalid");
    } else {
      require(lpLocked + lpAmount <= balanceOf(tx.origin), "SmartFarm#withdrawSMT: withdraw amount is invalid");
    }

    ISmartOtherAchievement ach = comptroller.getSmartOtherAchievement();
    if(ach.isFarmer(tx.origin))
      ach.removeFarmDistributor(tx.origin);

    UserInfo storage uInfo = userInfo[tx.origin];

    uint256 smtAmount = _tranferSmtToUser(account, lpAmount);
    require(smtAmount > 0, "SmartFarm#withdrawSMT: failed to sent SMT to staker");

    uInfo.balance = uInfo.balance - lpAmount;
    
    if(uInfo.tokenBalance < smtAmount) uInfo.tokenBalance = 0;
    else uInfo.tokenBalance = uInfo.tokenBalance - smtAmount;
    
    if(totalStaked < smtAmount) totalStaked = 0;
    else totalStaked = totalStaked - smtAmount;

    totalLpStaked = totalLpStaked - lpAmount;
    
    emit Withdrawn(tx.origin, smtAmount, lpAmount);

    return smtAmount;
  }

  /**
   * ///@notice Redeem SMT rewards from staking
   */
  function claimReward(uint256 _amount) 
    public override
  {
      UserInfo storage uInfo = userInfo[_msgSender()];
      uint256 rewards = rewardsOf(_msgSender());
      require(rewards > 0 , "SmartFarm#stakeSMT: Not enough rewards to claim");

      TransferHelper.safeTransfer(address(comptroller.getSMT()), _msgSender(), _amount);

      uInfo.rewards = uInfo.rewards - _amount;
      uInfo.havested = uInfo.havested + _amount;
      emit Claimed(_msgSender(), rewards);
  }
  
  function exit() external {
    withdrawSMT(msg.sender, balanceOf(msg.sender));
    claimReward(rewardsOf(msg.sender));
  }

  /**
   * Transfer smt token to contract.
   * Swap half as BUSD, 
   * Add Liquidity => LP token Lock
   */
  function _tranferSmtToContract(
    address _from, 
    uint256 _amount
  ) private returns(uint, uint) {
    IERC20 smtToken = comptroller.getSMT();
    IERC20 busdToken = comptroller.getBUSD();
  
    // Transfer SMT token from user to contract
    uint256 beforeBalance = smtToken.balanceOf(address(this));
    IERC20(smtToken).transferFrom(_from, address(this), _amount);
    uint256 amount = smtToken.balanceOf(address(this)) - beforeBalance;
    require(amount > 0, "SmartFarm#_transferSmtToContract: faild to transfer SMT token");

    // distribute farming tax
    {
      uint256 totalFarmingTax = _distributeFarmingTax(tx.origin, amount);
      amount = amount - totalFarmingTax;
    }

    // Swap half of SMT token to BUSD
    uint256 half = amount / 2;
    uint256 otherHalf = amount - half;

    uint256 beforeBusdBalance = busdToken.balanceOf(address(this));
    _swapTokensForBUSD(half);
    uint256 newBusdBalance = busdToken.balanceOf(address(this)) - beforeBusdBalance;

    // add liquidity
    (, , uint liquidity) = _addLiquidity(otherHalf, newBusdBalance);

    return (liquidity, amount);
  }

  /**
   * Distribute farming tax to ...
   */
  function _distributeFarmingTax(
    address account,
    uint256 farmingAmount
  ) internal returns (uint256) {
    // distribute farming tax
    // 10% goes to referral system
    // 3% goes to golden tree pool
    // 1% goes to development wallet
    // 1% goes to passive global share
    IERC20 smtToken = comptroller.getSMT();

    uint256 farmingTaxReferralAmount = farmingAmount * farmingTax_referral / 10_000;
    uint256 farmingTaxGoldenAmount = farmingAmount * farmingTax_golden / 10_000;
    uint256 farmingTaxDevAmount = farmingAmount * farmingTax_dev / 10_000;
    uint256 farmingTaxPassiveAmount = farmingAmount * farmingTax_passive / 10_000;

    uint256 totalPaid = 0;

    if(farmingTaxReferralAmount > 0) {
      ISmartLadder smartLadder = comptroller.getSmartLadder();
      TransferHelper.safeTransfer(address(smtToken), address(smartLadder), farmingTaxReferralAmount);
      smartLadder.distributeFarmingTax(account);

      totalPaid = totalPaid + farmingTaxReferralAmount;
    }
    
    if(farmingTaxGoldenAmount > 0) {
      IGoldenTreePool pool = comptroller.getGoldenTreePool();

      TransferHelper.safeTransfer(address(smtToken), address(pool), farmingTaxGoldenAmount);
      pool.notifyReward(farmingTaxGoldenAmount, account);

      totalPaid = totalPaid + farmingTaxGoldenAmount;
    }

    if(farmingTaxDevAmount > 0) {
      TransferHelper.safeTransfer(address(smtToken), address(feeAddress), farmingTaxDevAmount);
      totalPaid = totalPaid + farmingTaxDevAmount;
    }

    if(farmingTaxPassiveAmount > 0) {
      // TODO
      // transfer smt to passive pool and sync
      ISmartNobilityAchievement ach = comptroller.getSmartNobilityAchievement();
      TransferHelper.safeTransfer(address(smtToken), address(ach), farmingTaxPassiveAmount);
      ach.distributePassiveShare(farmingTaxPassiveAmount);
      totalPaid = totalPaid + farmingTaxPassiveAmount;
    }
    return totalPaid;
  }


  /**
   * Transfer smt token to user.
   * Remove liquidity
   * Swap half as SMT, 
   */
  function _tranferSmtToUser(address _to, uint256 _lpAmount) private returns(uint) {
    if(_lpAmount == 0) {
      return 0;
    }
    IERC20 smtToken = comptroller.getSMT();
    IERC20 busdToken = comptroller.getBUSD();
    IUniswapV2Router02 uniswapV2Router = comptroller.getUniswapV2Router();

    // Tranfer Penalty Fee to fee address
    uint256 feeAmount = _lpAmount * unstakingFee / 10_1000;

    address pair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(address(smtToken), address(busdToken));
    IERC20(pair).transfer(feeAddress, feeAmount);

    // Remove liquidity from dex
    (uint smtAmount, uint busdAmount) = _removeLiquidity(_lpAmount - feeAmount);

    // Swap BUSD to smt token
    uint256 beforeBalance = smtToken.balanceOf(address(this));
    _swapTokensForSMT(busdAmount);
    uint256 amount = uint256(smtAmount) + smtToken.balanceOf(address(this)) - beforeBalance;
    
    // Transfer SMT token to user
    IERC20(smtToken).transfer(_to, amount);
    
    return amount;
  }

  function _swapTokensForBUSD(uint256 tokenAmount) private {
    IERC20 smtToken = comptroller.getSMT();
    IERC20 busdToken = comptroller.getBUSD();
    IUniswapV2Router02 uniswapV2Router = comptroller.getUniswapV2Router();

    // generate the uniswap pair path of token -> busd
    address[] memory path = new address[](2);
    path[0] = address(smtToken);
    path[1] = address(busdToken);

    smtToken.approve(address(uniswapV2Router), tokenAmount);
    
    // make the swap
    uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
        tokenAmount,
        0,
        path,
        address(this),
        block.timestamp
    );
  }

  function _swapTokensForSMT(uint256 tokenAmount) private {
    IERC20 smtToken = comptroller.getSMT();
    IERC20 busdToken = comptroller.getBUSD();
    IUniswapV2Router02 uniswapV2Router = comptroller.getUniswapV2Router();

    // generate the uniswap pair path of token -> busd
    address[] memory path = new address[](2);
    path[0] = address(busdToken);
    path[1] = address(smtToken);

    busdToken.approve(address(uniswapV2Router), tokenAmount);
    
    // make the swap
    uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
        tokenAmount,
        0,
        path,
        address(this),
        block.timestamp
    );
  }

  function _addLiquidity(uint256 tokenAmount, uint256 busdAmount) 
    private 
    returns (uint amountA, uint amountB, uint liquidity)
  {
    IERC20 smtToken = comptroller.getSMT();
    IERC20 busdToken = comptroller.getBUSD();
    IUniswapV2Router02 uniswapV2Router = comptroller.getUniswapV2Router();

    // approve token transfer to cover all possible scenarios
    smtToken.approve(address(uniswapV2Router), tokenAmount);
    busdToken.approve(address(uniswapV2Router), busdAmount);
    
    // add the liquidity
    (amountA, amountB, liquidity) = uniswapV2Router.addLiquidity(
        address(smtToken),
        address(busdToken),
        tokenAmount,
        busdAmount,
        0, // slippage is unavoidable
        0, // slippage is unavoidable
        address(this),
        block.timestamp
    );
  }

  function _removeLiquidity(uint256 lpAmount) 
    private 
    returns (uint amountA, uint amountB)
  {
    IERC20 smtToken = comptroller.getSMT();
    IERC20 busdToken = comptroller.getBUSD();
    IUniswapV2Router02 uniswapV2Router = comptroller.getUniswapV2Router();

    // approve token transfer to cover all possible scenarios
    address pair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(address(smtToken), address(busdToken));
    IERC20(pair).approve(address(uniswapV2Router), lpAmount);    
    
    // add the liquidity
    (amountA, amountB) = uniswapV2Router.removeLiquidity(
        address(smtToken),
        address(busdToken),
        lpAmount,
        0, // slippage is unavoidable
        0, // slippage is unavoidable
        address(this),
        block.timestamp
    );
  }

}