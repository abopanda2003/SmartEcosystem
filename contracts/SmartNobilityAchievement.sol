// SPDX-License-Identifier: MIT

/**
 * Smart Passive Rewards Pool Contract
 * @author Liu
 */

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import './libs/TransferHelper.sol';

import './interfaces/IUniswapRouter.sol';
import './interfaces/IWETH.sol';
import './interfaces/ISmartComp.sol';
import './interfaces/ISmartNobilityAchievement.sol';
import "./interfaces/ISmartTokenCash.sol";
import "./interfaces/ISmartComp.sol";
import "./interfaces/IGoldenTreePool.sol";
import "./interfaces/ISmartLadder.sol";
import "./interfaces/ISmartArmy.sol";
import 'hardhat/console.sol';

contract SmartNobilityAchievement is UUPSUpgradeable, OwnableUpgradeable, ISmartNobilityAchievement {
  ISmartComp public comptroller;

  mapping(address => UserInfo) public _mapRewards;

  mapping(uint256 => uint256[]) public _mapChestStmSupply;
  mapping(uint256 => uint256[]) public _mapChestStmcSupply;
  
  uint256 private randNonce;

  // Nobility Types mapping
  mapping(uint256 => NobilityType) public nobilityTypes;
  uint256 public totalNobilityTypes;
  uint256 public totalRewardShares;

  address[] _nobleLeaders;

  // Account => Nobility type
  mapping(address => uint256) public userNobilities;
  // Nobility type => the number of whom owns it.
  mapping(uint256 => uint256) public userNobilityCounts;

  event NobilityTypeUpdated(uint256 id, NobilityType _type);
  event UserNobilityUpgraded(address indexed account, uint256 level);
  event RewardSwapped(uint256 reward);

  function initialize(address _comp) public initializer {
    __Ownable_init();
    __SmartNobilityAchievement_init_unchained(_comp);
  }

  function __SmartNobilityAchievement_init_unchained (address _comp)
    internal
    initializer  
  {
    comptroller = ISmartComp(_comp);

    totalNobilityTypes = 8;

    // initialize nobility types
    updateNobilityType(1, 'Folks', 1e18, 10, 2, 281e6,
      [uint256(0), 0, 0, 0, 0, 0, 0, 0, 0, 0],
      [uint256(0), 0, 0, 0, 0, 0, 0, 0, 0, 0]
    );

    _mapChestStmSupply[1] = [uint256(0), 0, 0, 0, 0, 0, 0];
    _mapChestStmcSupply[1] = [uint256(0), 0, 0, 0];

    updateNobilityType(2, 'Baron', 1e19, 15, 5,  41e6,
      [uint256(1e13), 1e14, 1e15, 1e16, 1e17, 1e18, 1e19,0 ,0, 0],
      [uint256(1e16), 1e17, 1e18, 0, 0, 0, 0, 0, 0, 0]
    );

    _mapChestStmSupply[2] = [uint256(2e9), 1e8, 1e7, 1e6, 1e5, 1e4, 1e3];
    _mapChestStmcSupply[2] = [uint256(1e5), 1e4, 1e3, 0];

    updateNobilityType(3, 'Count',  5e19,  20, 10,  41e5,
      [uint256(2.5e13), 2.5e14, 2.5e15, 2.5e16, 2.5e17, 2.5e18, 2.5e19, 0, 0, 0],
      [uint256(2.5e16), 2.5e17, 2.5e18, 0, 0, 0, 0, 0, 0, 0]
    );
    _mapChestStmSupply[3] = [uint256(1e8), 1e8, 1e7, 1e6, 1e5, 1e4, 1e3];
    _mapChestStmcSupply[3] = [uint256(1e5), 1e4, 1e3, 0];

    updateNobilityType(4, 'Viscount', 1e20,  25, 20, 1e5,
      [uint256(5e14), 5e15, 5e16, 5e17, 5e18, 5e19, 0 ,0, 0, 0],
      [uint256(5e16), 5e17, 5e18, 0, 0, 0, 0, 0, 0, 0]
    );
    _mapChestStmSupply[4] = [uint256(41e6), 1e7, 1e6, 1e5, 1e4, 1e3, 0];
    _mapChestStmcSupply[4] = [uint256(1e5), 1e4, 1e3, 0];
    
    updateNobilityType(5, 'Earl', 2e20,  30, 40,  10000,
      [uint256(8.5e15), 8.5e16, 8.5e17, 8.5e18, 8.5e19, 0 ,0 ,0 ,0, 0],
      [uint256(8.5e16), 8.5e17, 8.5e18, 0 ,0, 0, 0, 0, 0, 0]
    );
    _mapChestStmSupply[5] = [uint256(4.1e6), 1e6, 1e5, 1e4, 1e3, 0, 0];
    _mapChestStmcSupply[5] = [uint256(1e5), 1e4, 1e3, 0];

    updateNobilityType(6, 'Duke',  5e20,  35, 100,   1000,
      [uint256(2.5e16), 2.5e17, 2.5e18, 2.5e19, 2.5e20, 0, 0, 0, 0, 0],
      [uint256(2.5e17), 2.5e18, 2.5e19, 0, 0, 0, 0, 0, 0, 0]
    );
    _mapChestStmSupply[6] = [uint256(4.1e5), 1e5, 1e4, 1e3, 1e2, 0, 0];
    _mapChestStmcSupply[6] = [uint256(1e4), 1e3, 1e2, 0];

    updateNobilityType(7, 'Prince',   1e21, 40, 300, 100,
      [uint256(5e17), 5e18, 5e19, 5e20, 0, 0, 0, 0, 0, 0],
      [uint256(5e17), 5e18, 5e19, 0, 0, 0, 0, 0, 0, 0]
    );
    _mapChestStmSupply[7] = [uint256(4.1e4), 1e4, 1e3, 1e2, 0, 0, 0];
    _mapChestStmcSupply[7] = [uint256(1e4), 1e3, 1e2, 0];

    updateNobilityType(8, 'King',  2e21,  50,  700,  10,
      [uint256(5e18), 5e19, 5e20, 5e21, 0, 0, 0, 0, 0, 0],
      [uint256(1e18), 1e18, 1e19, 1e20, 0, 0, 0, 0, 0, 0]
    );
    _mapChestStmSupply[8] = [uint256(4.2e3), 1e3, 1e2, 10, 0, 0, 0];
    _mapChestStmcSupply[8] = [uint256(4.2e3), 1e3, 1e2, 10];
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  modifier onlySmartMember() {
    require(
      msg.sender == address(comptroller.getSmartArmy())
      || msg.sender == address(comptroller.getSmartLadder())
      || msg.sender == address(comptroller.getSmartFarm())
      || msg.sender == address(comptroller.getGoldenTreePool())
      || msg.sender == address(comptroller.getSMT())
      || msg.sender == owner(), 
      "only smart members");
      _;
  }

  function claimChestSMTReward(uint256 _amount) external override {
    uint256 userBalance = _mapRewards[msg.sender].chestRewards[0];
    uint256 poolBalance = comptroller.getSMT().balanceOf(address(this));
    require(userBalance - _amount >= 0, "user's balance overflow");
    require(poolBalance - _amount >= 0, "nobility pool's balance overflow");
    TransferHelper.safeTransfer(address(comptroller.getSMT()), msg.sender, _amount);
    _mapRewards[msg.sender].chestRewards[0] -= _amount;
  }

  function claimChestSMTCReward(uint256 _amount) external override {
    uint256 userBalance = _mapRewards[msg.sender].chestRewards[1];
    uint256 poolBalance = comptroller.getSMTC().balanceOf(address(this));
    require(userBalance - _amount >= 0, "user's balance overflow");
    require(poolBalance - _amount >= 0, "nobility pool's balance overflow");
    TransferHelper.safeTransfer(address(comptroller.getSMTC()), msg.sender, _amount);
    _mapRewards[msg.sender].chestRewards[1] -= _amount;
  }

  function claimNobleReward(uint256 _amount) external override {
    uint256 userBalance = _mapRewards[msg.sender].nobleRewards[1];
    uint256 poolBalance = comptroller.getSMTC().balanceOf(address(this));
    require(userBalance - _amount >= 0, "user's balance overflow");
    require(poolBalance - _amount >= 0, "nobility pool's balance overflow");
    TransferHelper.safeTransfer(address(comptroller.getSMTC()), msg.sender, _amount);
    _mapRewards[msg.sender].nobleRewards[1] -= _amount;
    _mapRewards[msg.sender].nobleRewards[0] += _amount;
  }

  function claimPassiveShareReward(uint256 _amount) external override {
    uint256 userBalance = _mapRewards[msg.sender].passiveShareRewards[1];
    uint256 poolBalance = comptroller.getSMTC().balanceOf(address(this));
    require(userBalance - _amount >= 0, "The amount to claim exceeds the balance");
    require(poolBalance - _amount >= 0, "nobility pool's balance overflow");
    TransferHelper.safeTransfer(address(comptroller.getSMTC()), msg.sender, _amount);
    _mapRewards[msg.sender].passiveShareRewards[1] -= _amount;
    _mapRewards[msg.sender].passiveShareRewards[0] += _amount;
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
    for(uint256 i=0; i<_nobleLeaders.length; i++) {
      address user = _nobleLeaders[i];
      if(_mapRewards[user].nobleRewards.length == 0)
        _mapRewards[user].nobleRewards = new uint256[](2);

      uint256 nobilityRewards = nobilityOf(user).goldenTreeRewards;
      _mapRewards[user].nobleRewards[1] += nobilityRewards * unitRewards / 10;
    }
  }

  function distributePassiveShare(
    uint256 _amount
  ) external override onlySmartMember {
    uint256 shares = 0;
    for(uint256 i=0; i<_nobleLeaders.length; i++){
      if(userNobilities[_nobleLeaders[i]] > 0)
        shares += nobilityOf(_nobleLeaders[i]).passiveShare;
    }
    
    if(shares > 0) {
      uint256 unitRewards = _amount / shares;
      for(uint256 i=0; i<_nobleLeaders.length; i++) {
        address user = _nobleLeaders[i];
        if(_mapRewards[user].passiveShareRewards.length == 0)
          _mapRewards[user].passiveShareRewards = new uint256[](2);
        uint256 userShare = nobilityOf(user).passiveShare;
        _mapRewards[user].passiveShareRewards[1] += userShare * unitRewards;
      }
    }
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
  ) external override returns(bool) {

    require(msg.sender == address(comptroller.getGoldenTreePool()), "SmartAchievement#notifyUpdate: only golden tree pool");
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
        _mapRewards[account].checkRewardUpdated = block.timestamp;
      } else if(id > 2) {
        updateChestReward(account);
      }
      emit UserNobilityUpgraded(account, id);
      return true;
    }
    return false;
  }

  function isPossibleNobilityReward(address account) public view returns(bool) {
    uint256[] memory smtTotalSupply = _mapChestStmSupply[userNobilities[account]];
    uint256[] memory smtcTotalSupply = _mapChestStmcSupply[userNobilities[account]];

    uint256 i;
    for(i=0; i<smtTotalSupply.length; i++)
      if(smtTotalSupply[i] > 0) break;

    if(i == smtTotalSupply.length) {
      for(i=0; i<smtcTotalSupply.length; i++)
        if(smtcTotalSupply[i] > 0) break;
      if(i == smtcTotalSupply.length) return false;
    }
    return true;
  }

  function updateChestReward(address account) internal {
    uint256 rewardWeeks = uint256(block.timestamp - _mapRewards[account].checkRewardUpdated) / 7 / 86400;
    if(_mapRewards[account].chestRewards.length < 2)
        _mapRewards[account].chestRewards = new uint256[](2);

    uint256[] memory smtTotalSupply = _mapChestStmSupply[userNobilities[account]];
    uint256[] memory smtcTotalSupply = _mapChestStmcSupply[userNobilities[account]];
    for(uint i = 0; i < rewardWeeks; i++) {
      for(;isPossibleNobilityReward(account);) {
        randNonce = randNonce + 1;
        (uint256 coinIndex, uint256 index, uint256 reward) = getChestRandomReward(randNonce, userNobilities[account]);
        if(coinIndex == 0 && smtTotalSupply[index] > 0) {
          _mapRewards[account].chestRewards[coinIndex] += reward;
          _mapChestStmSupply[userNobilities[account]][index] -= 1;
          break;
        }
        if(coinIndex == 1 && smtcTotalSupply[index] > 0) {
          _mapRewards[account].chestRewards[coinIndex] += reward;
          _mapChestStmcSupply[userNobilities[account]][index] -= 1;
          break;
        }
      }
    }

    uint256 weeklyRewards = rewardWeeks * 7 * 86400;
    _mapRewards[account].checkRewardUpdated += weeklyRewards;
  }

  function getChestRandomReward(uint256 nonce, uint256 nobilityType) 
                        private view returns(uint256, uint256, uint256) {

    NobilityType memory _type = nobilityTypes[nobilityType];

    uint256 seed = uint256(keccak256(abi.encode(nonce, msg.sender, block.timestamp)));
    uint256 coinIndex = _getRandomNumebr(seed, 2);
    uint256 selectedReward = 0;
    uint256 selectedIndex = 0;
    if(coinIndex == 0){
      selectedIndex = _getRandomNumebr(seed * 7, _type.chestSMTRewardPool.length);
      selectedReward = _type.chestSMTRewardPool[selectedIndex];
    } else {
      selectedIndex = _getRandomNumebr(seed * 7, _type.chestSMTCRewardPool.length);
      selectedReward = _type.chestSMTCRewardPool[selectedIndex];
    }
    return ( coinIndex, selectedIndex, selectedReward );
  }

  function _getRandomNumebr(uint256 seed, uint256 mod) view private returns(uint256) {
    if(mod == 0) {
      return 0;
    }
    return uint256(keccak256(abi.encode(block.timestamp, block.difficulty, block.coinbase, blockhash(block.number + 1), seed, block.number))) % mod;
  }

  /**
   * @dev Update Nobility Type
   */
  function updateNobilityType(
    uint256 id, 
    string memory title,
    uint256 growthRequried,
    uint256 goldenTreeRewards,
    uint256 passiveShare,
    uint256 availableTitles,
    uint256[10] memory _chestSMTRewards,
    uint256[10] memory _chestSMTCRewards
  ) public onlyOwner {
    require(id <= totalNobilityTypes && id > 0, "SmartAchievement#_updateNobilityType: invalid id");
    NobilityType storage _type = nobilityTypes[id];
    _type.title          = title;
    _type.growthRequried = growthRequried;
    _type.goldenTreeRewards = goldenTreeRewards;
    _type.passiveShare   = passiveShare;
    _type.availableTitles = availableTitles;

    for(uint256 i = 0; i < _chestSMTRewards.length; i++) {
      if(_chestSMTRewards[i] > 0) {
        _type.chestSMTRewardPool.push(_chestSMTRewards[i]);
      }
    }

    for(uint256 j = 0; j < _chestSMTCRewards.length; j++) {
      if(_chestSMTCRewards[j] > 0) {
        _type.chestSMTCRewardPool.push(_chestSMTCRewards[j]);
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
  function swapDistribute(uint _amount) 
    external override onlySmartMember
  {
    IERC20 smt  = comptroller.getSMT();
    IERC20 weth = comptroller.getWBNB();
    address[] memory wethpath = new address[](2);
    wethpath[0] = address(smt);
    wethpath[1] = address(weth);

    IUniswapV2Router02 _uniswapV2Router = comptroller.getUniswapV2Router();

    uint256 beforeBalance = address(this).balance;
    smt.approve(address(_uniswapV2Router), _amount);
    _uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
        _amount,
        0,
        wethpath,
        address(this),
        block.timestamp + 3600
    );
    uint256 wethAmount = address(this).balance - beforeBalance;
    // IWETH(address(weth)).deposit{value: wethAmount}();
    
    emit RewardSwapped(wethAmount);
  }

  function indexOf(address[] memory array, address value) public pure returns(uint) {
      uint i = 0;
      while (array[i] != value) i++;
      return i;
  }

  function contain(address[] memory array, address value) public pure returns(bool) {
      uint i = 0;
      for(i=0; i<array.length; i++)
          if(array[i] == value) break;      
      if(i < array.length) return true;
      return false;
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
        _nobleLeaders[i] = _nobleLeaders[i+1]; i++;
      }
      _nobleLeaders.pop();
  }

  //to recieve ETH from uniswapV2Router when swaping
  receive() external payable {}
}