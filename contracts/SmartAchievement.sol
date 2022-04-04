// SPDX-License-Identifier: MIT

/**
 * Smart Passive Rewards Pool Contract
 * @author Liu
 */

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


// import './libs/StableMath.sol';
import './libs/TransferHelper.sol';

import './interfaces/IUniswapRouter.sol';
import './interfaces/IWETH.sol';
import './interfaces/ISmartComp.sol';
import './interfaces/ISmartAchievement.sol';
import "./interfaces/ISmartTokenCash.sol";
import "./interfaces/ISmartComp.sol";
import "./interfaces/IGoldenTreePool.sol";
import "./interfaces/ISmartLadder.sol";
import "./interfaces/ISmartArmy.sol";
import 'hardhat/console.sol';

contract SmartAchievement is UUPSUpgradeable, OwnableUpgradeable, ISmartAchievement {
  // using StableMath for uint256;
  // using SafeMath for uint256;
  // using EnumerableSet for EnumerableSet.AddressSet;

  ISmartComp public comptroller;
  address public smtcTokenAddress;

  bool public swapEnabled;
  uint256 public limitPerSwap;

  uint256 public constant DURATION = 7 days;

  // Timestamp for current period finish
  uint256 public periodFinish;
  // RewardRate for the rest of the PERIOD
  uint256 public rewardRate;
  // Last time any user took action
  uint256 public lastUpdateTime;
  // Ever increasing rewardPerToken rate, based on % of total supply
  uint256 public rewardPerTokenStored;

  mapping(address => uint256) public userRewardPerTokenPaid;
  mapping(address => uint256) public rewards;
  
  mapping(address => uint256) public chestSMTRewards;
  mapping(address => uint256) public chestSMTCRewards;
  mapping(address => uint256) public checkRewardUpdated;
  mapping(address => uint256) public nobleRewards; // Noble SMTC Reward
  mapping(address => uint256) public farmRewards; // Farmer SMTC Reward
  mapping(address => uint256) public supSmtRewards; // Surprize Reward
  mapping(address => uint256) public supSmtcRewards; // Surprize Reward
  
  uint256 private randNonce;

  // Nobility Types mapping
  mapping(uint256 => NobilityType) public nobilityTypes;
  uint256 public totalNobilityTypes;
  
  uint256 public totalRewardShares;

  address[] _farmers;
  address[] _nobleLeaders;

  uint256[][9] supPool;
  uint256[9] supTotalSupply;


  // Account => Nobility type
  mapping(address => uint256) public userNobilities;
  // Nobility type => the number of whom owns it.
  mapping(uint256 => uint256) public userNobilityCounts;

  event NobilityTypeUpdated(uint256 id, NobilityType _type);
  event UserNobilityUpgraded(address indexed account, uint256 level);
  event RewardAdded(uint256 reward);
  event RewardPaid(address indexed user, uint256 reward);
  event RewardSwapped(uint256 reward);


  function initialize(address _comp, address _smtcToken) public initializer {
		__Ownable_init();
    __SmartAchievement_init_unchained(_comp, _smtcToken);
  }


  function __SmartAchievement_init_unchained(address _comp, address _smtcToken)
    internal
    initializer
  {
    comptroller = ISmartComp(_comp);
    smtcTokenAddress = _smtcToken;

    totalNobilityTypes = 8;

    // initialize nobility types
    _updateNobilityType(1, 'Folks', 1, 10, 2, 281e6,
      [uint256(0), 0, 0, 0, 0, 0, 0, 0, 0, 0],
      [uint256(0), 0, 0, 0, 0, 0, 0, 0, 0, 0]);

    _updateNobilityType(2, 'Baron', 10, 15, 5,  41e6,
      [uint256(1e16), 1e17, 1e18, 0, 0, 0, 0, 0, 0, 0],
      [uint256(1e13), 1e14, 1e15, 1e16, 1e17, 1e18, 1e19,0 ,0, 0]);

    _updateNobilityType(3, 'Count',  50,  20, 10,  41e5,
      [uint256(2.5e16), 2.5e17, 2.5e18, 0, 0, 0, 0, 0, 0, 0], 
      [uint256(2.5e13), 2.5e14, 2.5e15, 2.5e16, 2.5e17, 2.5e18, 2.5e19, 0, 0, 0]);

    _updateNobilityType(4, 'Viscount', 100,  25, 20, 1e5,
      [uint256(5e16), 5e17, 5e18, 0, 0, 0, 0, 0, 0, 0],
      [uint256(5e14), 5e15, 5e16, 5e17, 5e18, 5e19, 0 ,0, 0, 0]);
    
    _updateNobilityType(5, 'Earl',     200,  30, 40,  10000,
      [uint256(8.5e16), 8.5e17, 8.5e18, 0 ,0, 0, 0, 0, 0, 0],
      [uint256(8.5e15), 8.5e16, 8.5e17, 8.5e18, 8.5e19, 0 ,0 ,0 ,0, 0]);

    _updateNobilityType(6, 'Duke',     500,  35, 100,   1000,
      [uint256(2.5e17), 2.5e18, 2.5e19, 0, 0, 0, 0, 0, 0, 0],
      [uint256(2.5e16), 2.5e17, 2.5e18, 2.5e19, 2.5e20, 0, 0, 0, 0, 0]);

    _updateNobilityType(7, 'Prince',   1000, 40, 300, 100,
      [uint256(5e17), 5e18, 5e19, 0, 0, 0, 0, 0, 0, 0], 
      [uint256(5e17), 5e18, 5e19, 5e20, 0, 0, 0, 0, 0, 0]);

    _updateNobilityType(8, 'King',  2000,  50,  700,  10,
      [uint256(1e18), 1e18, 1e19, 1e20, 0, 0, 0, 0, 0, 0],
      [uint256(5e18), 5e19, 5e20, 5e21, 0, 0, 0, 0, 0, 0]);

    uint256[9] memory smt = [uint256(1e22), 1e21, 1e20, 1e19, 1e18, 1e17, 1e16, 1e15, 1e14]; // SMT
    uint256[9] memory smtc = [uint256(1e21), 1e20, 1e19, 1e18, 1e17, 1e16, 1e15, 1e14, 1e13];  // SMTC
    supPool = [smt, smtc];

    supTotalSupply = [uint256(10), 100, 1000, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9]; // Total Supply
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}


  /** @dev Updates the reward for a given address, before executing function */
  modifier updateReward(address _account) {
    // Setting of global vars
    uint256 newRewardPerToken = rewardPerToken();
    // If statement protects against loss in initialisation case
    if (newRewardPerToken > 0) {
      rewardPerTokenStored = newRewardPerToken;
      lastUpdateTime = lastTimeRewardApplicable();
      // Setting of personal vars based on new globals
      if (_account != address(0)) {
        rewards[_account] = earned(_account);
        userRewardPerTokenPaid[_account] = newRewardPerToken;
      }
    }
    _;
  }

  modifier onlySmartMember() {
    require(
      msg.sender == address(comptroller.getSmartArmy())
      || msg.sender == address(comptroller.getSmartLadder())
      || msg.sender == address(comptroller.getSmartFarm())
      || msg.sender == address(comptroller.getGoldenTreePool())
      || msg.sender == address(comptroller.getSmartBridge())
      || msg.sender == owner(), 
      "only smart members can access to this function");
      _;
  }

  /***************************************
                    ACTIONS
  ****************************************/
  /**
   * @dev Claims outstanding rewards for the sender.
   * First updates outstanding reward allocation and then transfers.
   */
  function claimReward() external override updateReward(msg.sender) onlySmartMember {
    uint256 reward = rewards[msg.sender];
    if (reward > 0) {
      rewards[msg.sender] = 0;
      IWETH(address(comptroller.getWBNB())).withdraw(reward);
      TransferHelper.safeTransferETH(msg.sender, reward);
      emit RewardPaid(msg.sender, reward);
    }
  }

  function claimChestReward() external override {
    // update chest rewards before claim
    updateChestReward(msg.sender);

    if(chestSMTRewards[msg.sender] > 0) {
      TransferHelper.safeTransfer(address(comptroller.getSMT()), msg.sender, chestSMTRewards[msg.sender]);
      chestSMTRewards[msg.sender] = 0;
    }

    if(chestSMTCRewards[msg.sender] > 0) {
      TransferHelper.safeTransfer(smtcTokenAddress, msg.sender, chestSMTCRewards[msg.sender]);
      chestSMTCRewards[msg.sender] = 0;
    }
  }

  function claimNobleReward(uint256 _amount) external override {
    uint256 balance = nobleRewards[msg.sender];
    require(balance - _amount >= 0, "The amount to claim exceeds the balance");

    TransferHelper.safeTransfer(smtcTokenAddress, msg.sender, _amount);
    nobleRewards[msg.sender] = nobleRewards[msg.sender] - _amount;
  }

  function claimFarmReward(uint256 _amount) external override {
    uint256 balance = farmRewards[msg.sender];
    require(balance - _amount >= 0, "The amount to claim exceeds the balance");

    if(farmRewards[msg.sender] > 0) {
      TransferHelper.safeTransfer(smtcTokenAddress, msg.sender, _amount);
      farmRewards[msg.sender] = farmRewards[msg.sender] - _amount;
    }
  }

  function claimSurprizeSMTReward(uint256 _amount) external override {
    uint256 balance = supSmtRewards[msg.sender];
    require(balance - _amount >= 0, "The amount to claim exceeds the balance");

    TransferHelper.safeTransfer(address(comptroller.getSMT()), msg.sender, _amount);
    supSmtRewards[msg.sender] = supSmtRewards[msg.sender] - _amount;
  }

  function claimSurprizeSMTCReward(uint256 _amount) external override {
    uint256 balance = supSmtcRewards[msg.sender];
    require(balance - _amount >= 0, "The amount to claim exceeds the balance");

    TransferHelper.safeTransfer(smtcTokenAddress, msg.sender, _amount);
    supSmtcRewards[msg.sender] = supSmtcRewards[msg.sender] - _amount;
  }


  /***************************************
                    GETTERS
  ****************************************/
  /**
   * @dev Gets the RewardsToken
   */
  function getRewardToken() public view returns (IERC20) {
    return comptroller.getWBNB();
  }

  /**
   * @dev Gets the last applicable timestamp for this reward period
   */
  function lastTimeRewardApplicable() public view returns (uint256) {
    return block.timestamp < periodFinish? block.timestamp : periodFinish;
  }

  /**
   * @dev Calculates the amount of unclaimed rewards per token since last update,
   * and sums with stored to give the new cumulative reward per token
   * @return 'Reward' per staked token
   */
  function rewardPerToken() public view returns (uint256) {
    // If there is no StakingToken liquidity, avoid div(0)
    uint256 stakedTokens = totalRewardShares * 1e9;
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

  function balanceOf(address _account) public view returns(uint256) {
    NobilityType memory _type = nobilityOf(_account);

    uint256 totalUsersOn = userNobilityCounts[userNobilities[_account]];
    if(totalUsersOn == 0) {
      return 0;
    }
    return _type.passiveShare * 1e9 / totalUsersOn;
  }

  /**
   * @dev Calculates the amount of unclaimed rewards a user has earned
   * @param _account User address
   * @return Total reward amount earned
   */
  function earned(address _account) public view returns (uint256) {
    // current rate per token - rate user previously received
    uint256 userRewardDelta = rewardPerToken() - userRewardPerTokenPaid[_account];
    // new reward = staked tokens * difference in rate
    uint256 userNewReward = balanceOf(_account) * userRewardDelta / 1e18;
    // add to previous rewards
    return rewards[_account] + userNewReward;
  }

  /**
   * @dev get Nobility type of account 
   */
  function nobilityOf(address account) public view override returns(NobilityType memory) {
    return nobilityTypes[userNobilities[account]];
  }

  /**
   * @dev get Title of Nobility type of account 
   */
  function nobilityTitleOf(address account) public view override returns(string memory) {
    return nobilityOf(account).title;
  }

  function addFarmDistributor(address _account)
              external override onlySmartMember {
    require(_account != address(0x0), "account address can't be zero address");
    addFarmUser(_account);
  }

  function removeFarmDistributor(address _account) 
              external override onlySmartMember {
    require(_account != address(0x0), "account address can't be zero address");
    removeFarmUser(_account);
  }

  /**
   * @dev distribute rewards to all the noble leaders
   */
  function distributeToNobleLeaders(uint256 _amount) 
                  external override onlySmartMember {
    uint256 portions = 0;
    for(uint256 i = 1 ; i <= totalNobilityTypes; i++)
      portions += userNobilityCounts[i];
    
    if(portions == 0) return;
    uint256 unitRewards = _amount / portions;
    for(uint256 i=0; i<_nobleLeaders.length; i++){
      address user = _nobleLeaders[i];
      uint256 nobilityRewards = nobilityOf(user).goldenTreeRewards;
      nobleRewards[user] = nobilityRewards * unitRewards / 10;
    }
  }

  /**
   * @dev distribute rewards to all the farmers
   */
  function distributeToFarmers(uint256 _amount)
              external override onlySmartMember {
    
    if(_farmers.length == 0) return;
    uint256 unitRewards = _amount / _farmers.length;

    for(uint256 i=0; i<_farmers.length; i++){
      address user = _farmers[i];
      farmRewards[user] = unitRewards;
    }
  }

  /**
   * @dev distribute surprize rewards
   */
  function distributeSurprizeReward(address _account)
                    external override onlySmartMember {
  
    uint256 seed = uint256(keccak256(abi.encode(block.number, msg.sender, block.timestamp)));
    uint256 poolIndex = _getRandomNumebr(seed, supTotalSupply.length);
    uint256 coinIndex = poolIndex % 2;
    
    uint256 selectedReward = supPool[coinIndex][poolIndex];
    if(coinIndex == 0) supSmtRewards[_account] = selectedReward;
    else supSmtcRewards[_account] = selectedReward;

    supTotalSupply[poolIndex] = supTotalSupply[poolIndex] - 1;
  }

  /**
   * @dev Check Nobility upgradeable from growth balance to growth balance
   */
  function isUpgradeable(uint256 from, uint256 to) public view override returns(bool, uint256) {
    for(uint256 i = 1 ; i <= totalNobilityTypes; i++) {
      NobilityType memory _type = nobilityTypes[i];
      if(from < _type.growthRequried && to >= _type.growthRequried) {
        return (true, i);
      }
    }
    return (false, 0);
  }

  function notifyGrowth(
    address account,
    uint256 oldBalance,
    uint256 newBalance
  ) public override updateReward(account) returns(bool) {

    require(_msgSender() == address(comptroller.getGoldenTreePool()), "SmartAchievement#notifyUpdate: only golden tree pool");
    (bool possible, uint256 id) = isUpgradeable(oldBalance, newBalance);
    if(possible) {
      userNobilities[account] = id;
      userNobilityCounts[id] = userNobilityCounts[id] + 1;

      ISmartArmy army = comptroller.getSmartArmy();
      if(id == 1 && army.isActiveLicense(account)) addNobleUser(account);

      if(id > 1) {
        userNobilityCounts[id - 1] = userNobilityCounts[id - 1] - 1;
      }

      if(id == 2) { // From Nobility = 2 : Baron Chest rewards start
        checkRewardUpdated[account] = block.timestamp;
      } else if(id > 2) {
        updateChestReward(account);
      }
      emit UserNobilityUpgraded(account, id);
      return true;
    }
    return false;
  }

  function updateChestReward(address account) internal {
    uint256 rewardWeeks = uint256(block.timestamp - checkRewardUpdated[account]) / 7 / 86400;

    for(uint i = 0; i < rewardWeeks; i++) {
      randNonce = randNonce + 1;
      (uint256 smtReward, uint256 smtcReward) = getRandomReward(randNonce, userNobilities[account]);

      chestSMTRewards[account] = chestSMTRewards[account] + smtReward;
      chestSMTCRewards[account] = chestSMTCRewards[account] + smtcReward;
    }
    uint256 weeklyRewards = rewardWeeks * 7 * 86400;
    checkRewardUpdated[account] = checkRewardUpdated[account] + weeklyRewards;
  }

  function getRandomReward(uint256 nonce, uint256 nobilityType) 
                        private view returns(uint256, uint256) {

    NobilityType memory _type = nobilityTypes[nobilityType];

    uint256 seed = uint256(keccak256(abi.encode(nonce, msg.sender, block.timestamp)));
    uint256 chestSMTIndex = _getRandomNumebr(seed, _type.chestSMTRewards.length);
    uint256 chestSMTCIndex = (chestSMTIndex * 3) % _type.chestSMTCRewards.length;

    return (
      _type.chestSMTRewards[chestSMTIndex],
      _type.chestSMTCRewards[chestSMTCIndex]
    );
  }

  function _getRandomNumebr(uint256 seed, uint256 mod) view private returns(uint256) {
    if(mod == 0) {
      return 0;
    }
    return uint256(keccak256(abi.encode(block.timestamp, block.difficulty, block.coinbase, blockhash(block.number + 1), seed, block.number))) % mod;
  }

  /***************************************
                    ADMIN
  ****************************************/

  function updateNobilityType(
    uint256 id, 
    string memory title, 
    uint256 growthRequried,
    uint256 goldenTreeRewards,
    uint256 passiveShare,
    uint256 availableTitles,
    uint256[10] memory _chestSMTRewards,
    uint256[10] memory _chestSMTCRewards
  ) external onlyOwner {
      _updateNobilityType(
        id, 
        title, 
        growthRequried, 
        goldenTreeRewards, 
        passiveShare, 
        availableTitles, 
        _chestSMTRewards, 
        _chestSMTCRewards
      );
  }

  /**
   * @dev Update Nobility Type
   */
  function _updateNobilityType(
    uint256 id, 
    string memory title,
    uint256 growthRequried,
    uint256 goldenTreeRewards,
    uint256 passiveShare,
    uint256 availableTitles,
    uint256[10] memory _chestSMTRewards,
    uint256[10] memory _chestSMTCRewards
  ) private {
    require(id <= totalNobilityTypes && id > 0, "SmartAchievement#_updateNobilityType: invalid id");
    NobilityType storage _type = nobilityTypes[id];
    _type.title          = title;
    _type.growthRequried = growthRequried;
    _type.goldenTreeRewards = goldenTreeRewards;
    _type.passiveShare   = passiveShare;
    _type.availableTitles = availableTitles;

    for(uint256 i = 0; i < _chestSMTRewards.length; i++) {
      if(_chestSMTRewards[i] > 0) {
        _type.chestSMTRewards.push(_chestSMTRewards[i]);
      }
    }

    for(uint256 j = 0; j < _chestSMTCRewards.length; j++) {
      if(_chestSMTCRewards[j] > 0) {
        _type.chestSMTCRewards.push(_chestSMTCRewards[j]);
      }
    }

    uint256 temp = 0;
    for(uint256 i = 1; i <= totalNobilityTypes; i++) {
      temp += nobilityTypes[id].passiveShare;
    }
    totalRewardShares = temp;

    emit NobilityTypeUpdated(id, _type);
  }

  /**
   * Swap and distribute SMT token to BNB
   */
  function swapDistribute() 
    external override onlySmartMember
  {
    IERC20 smt  = comptroller.getSMT();
    uint256 smtBalance = smt.balanceOf(address(this));
    if(!swapEnabled || smtBalance <= limitPerSwap) {
      return;
    }

    IERC20 weth = comptroller.getWBNB();
    address[] memory wethpath = new address[](2);
    wethpath[0] = address(smt);
    wethpath[1] = address(weth);

    IUniswapV2Router02 _uniswapV2Router = comptroller.getUniswapV2Router();

    uint256 beforeBalance = address(this).balance;
    uint256 swapAmount = smtBalance > limitPerSwap ? limitPerSwap : smtBalance;
    smt.approve(address(_uniswapV2Router), swapAmount);
    _uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
        swapAmount,
        0,
        wethpath,
        address(this),
        block.timestamp + 3600
    );
    uint256 wethAmount = address(this).balance - beforeBalance;
    IWETH(address(weth)).deposit{value: wethAmount}();
    
    if(wethAmount > 0) {
      notifyRewardAmount(wethAmount);
    }
    emit RewardSwapped(wethAmount);
  }

  /**
   * @dev Notifies the contract that new rewards have been added.
   * Calculates an updated rewardRate based on the rewards in period.
   * @param _reward Units of RewardToken that have been added to the pool
   */
  function notifyRewardAmount(uint256 _reward)
    internal
    updateReward(address(0))
  {
    uint256 currentTime = block.timestamp;
    // If previous period over, reset rewardRate
    if (currentTime >= periodFinish) {
      rewardRate = _reward / DURATION;
    }
    // If additional reward to existing period, calc sum
    else {
      uint256 remaining = periodFinish - currentTime;
      uint256 leftover = remaining * rewardRate;
      rewardRate = (_reward + leftover) / DURATION;
    }

    lastUpdateTime = currentTime;
    periodFinish = currentTime + DURATION;

    emit RewardAdded(_reward);
  }

  function indexOf(address[] memory array, address value) public pure returns(uint) {
      uint i = 0;
      while (array[i] != value) {
          i++;
      }
      return i;
  }

  function contain(address[] memory array, address value) public pure returns(bool) {
      uint i = 0;
      for(i=0; i<array.length; i++)
          if(array[i] == value) break;
      
      if(i < array.length) return true;
      return false;
  }

  function isFarmer(address _account) external override view returns(bool) {
    return contain(_farmers, _account);
  }

  function isNobleLeader(address _account) external override view returns(bool) {
    return contain(_nobleLeaders, _account);
  }

  function addNobleUser(address value) internal {
      _nobleLeaders.push(value);
  }

  function removeNobleUser(address value) internal {
      require(_nobleLeaders.length > 0, "The array length is zero now.");
      uint i = indexOf(_nobleLeaders, value);
      removeIndexOnNoble(i);
  }

  function removeIndexOnNoble(uint256 i) internal {
      require(_nobleLeaders.length > 0, "The array length is zero now.");
      while (i<_nobleLeaders.length-1) {
          _nobleLeaders[i] = _nobleLeaders[i+1];
          i++;
      }
      _nobleLeaders.pop();
  }

  function addFarmUser(address value) internal {
      _farmers.push(value);
  }

  function removeFarmUser(address value) internal {
      require(_farmers.length > 0, "The array length is zero now.");
      uint i = indexOf(_farmers, value);
      removeIndexOnFarmer(i);
  }

  function removeIndexOnFarmer(uint256 i) internal {
      require(_farmers.length > 0, "The array length is zero now.");
      while (i<_farmers.length-1) {
          _farmers[i] = _farmers[i+1];
          i++;
      }
      _farmers.pop();
  }

  //to recieve ETH from uniswapV2Router when swaping
  receive() external payable {}
}