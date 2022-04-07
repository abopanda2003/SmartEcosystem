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
import './interfaces/ISmartOtherAchievement.sol';
import "./interfaces/ISmartTokenCash.sol";
import "./interfaces/ISmartComp.sol";
import "./interfaces/IGoldenTreePool.sol";
import "./interfaces/ISmartLadder.sol";
import "./interfaces/ISmartArmy.sol";
import 'hardhat/console.sol';

contract SmartOtherAchievement is UUPSUpgradeable, OwnableUpgradeable, ISmartOtherAchievement {
  ISmartComp public comptroller;
  address[] _farmers;
  uint256[][9] supPool;
  uint256[][9] supTotalSupply;
  uint256 private randNonce;
  mapping(address => UserInfo) _mapRewards;

  event RewardSwapped(uint256 reward);

  function initialize(address _comp) public initializer {
    __Ownable_init();
    __SmartOtherAchievement_init_unchained(_comp);
  }

  function __SmartOtherAchievement_init_unchained(address _comp)
    internal
    initializer  
  {
    comptroller = ISmartComp(_comp);

    uint256[9] memory smt = [uint256(1e22), 1e21, 1e20, 1e19, 1e18, 1e17, 1e16, 1e15, 1e14]; // SMT
    uint256[9] memory smtc = [uint256(1e21), 1e20, 1e19, 1e18, 1e17, 1e16, 1e15, 1e14, 1e13];  // SMTC
    supPool = [smt, smtc];

    uint256[9] memory smtSupply = [uint256(10), 100, 1000, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9]; // Total Supply
    uint256[9] memory smtcSupply = [uint256(10), 100, 1000, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9]; // Total Supply
    supTotalSupply = [smtSupply, smtcSupply];
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

  function claimFarmReward(uint256 _amount) external override {
    uint256 userBalance = _mapRewards[msg.sender].farmRewards[1];
    uint256 poolBalance = comptroller.getSMTC().balanceOf(address(this));
    require(userBalance - _amount >= 0, "user's balance overflow");
    require(poolBalance - _amount >= 0, "nobility pool's balance overflow");
    TransferHelper.safeTransfer(address(comptroller.getSMTC()), msg.sender, _amount);
    _mapRewards[msg.sender].farmRewards[1] -= _amount;
    _mapRewards[msg.sender].farmRewards[0] += _amount;
  }

  function claimSurprizeSMTReward(uint256 _amount) external override {
    uint256 userBalance = _mapRewards[msg.sender].surprizeRewards[0];
    uint256 poolBalance = comptroller.getSMT().balanceOf(address(this));
    require(userBalance - _amount >= 0, "The amount to claim exceeds the balance");
    require(poolBalance - _amount >= 0, "nobility pool's balance overflow");
    TransferHelper.safeTransfer(address(comptroller.getSMT()), msg.sender, _amount);
    _mapRewards[msg.sender].surprizeRewards[0] -= _amount;
  }

  function claimSurprizeSMTCReward(uint256 _amount) external override {
    uint256 userBalance = _mapRewards[msg.sender].surprizeRewards[1];
    uint256 poolBalance = comptroller.getSMTC().balanceOf(address(this));
    require(userBalance - _amount >= 0, "The amount to claim exceeds the balance");
    require(poolBalance - _amount >= 0, "nobility pool's balance overflow");
    TransferHelper.safeTransfer(address(comptroller.getSMTC()), msg.sender, _amount);
    _mapRewards[msg.sender].surprizeRewards[1] -= _amount;
  }

  function claimSellTaxReward(uint256 _amount) external override {
    uint256 userBalance = _mapRewards[msg.sender].sellTaxRewards[1];
    uint256 poolBalance = comptroller.getSMTC().balanceOf(address(this));
    require(userBalance - _amount >= 0, "The amount to claim exceeds the balance");
    require(poolBalance - _amount >= 0, "nobility pool's balance overflow");
    TransferHelper.safeTransfer(address(comptroller.getSMTC()), msg.sender, _amount);
    _mapRewards[msg.sender].sellTaxRewards[1] -= _amount;
    _mapRewards[msg.sender].sellTaxRewards[0] += _amount;
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
   * @dev distribute sell tax
   */
  function distributeSellTax(uint256 _amount) 
              external override onlySmartMember {
    
    ISmartArmy army = comptroller.getSmartArmy();
    address[] memory users = army.licensedUsers();
    uint256 totalPortions = 0;
    for(uint256 i=0; i<users.length; i++) 
      totalPortions += army.licensePortionOf(users[i]);
    for(uint256 i=0; i<users.length; i++) {
      if(_mapRewards[users[i]].sellTaxRewards.length == 0)
        _mapRewards[users[i]].sellTaxRewards = new uint256[](2);

      uint256 portion = army.licensePortionOf(users[i]);
      if(portion == 0) continue;
      _mapRewards[users[i]].sellTaxRewards[1] += portion * _amount / totalPortions;
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
      if(_mapRewards[user].farmRewards.length == 0)
        _mapRewards[user].farmRewards = new uint256[](2);
      _mapRewards[user].farmRewards[1] += unitRewards;
    }
  }

  function isPossibleSurprizeReward() public view returns(bool) {
    uint256 i;
    for(i=0; i<2; i++) {
      uint256 j;
      for(j=0; j<supTotalSupply[i].length; j++)
        if(supTotalSupply[i][j] > 0) break;      
      if(j < supTotalSupply[i].length) break;
    }
    if(i == 2) return false;
    return true;
  }

  function distributeSurprizeReward(
    address _account, 
    uint256 _claims
  ) external override onlySmartMember {

    if(_mapRewards[_account].surprizeRewards.length <2)
        _mapRewards[_account].surprizeRewards = new uint256[](2);

    for(uint256 i=0; i<_claims; i++) {
      for(;isPossibleSurprizeReward();) {
        uint256 seed = uint256(keccak256(abi.encode(block.number, msg.sender, block.timestamp)));
        uint256 poolIndex = _getRandomNumebr(seed, supTotalSupply.length);
        uint256 coinIndex = poolIndex % 2;
        if(supTotalSupply[coinIndex][poolIndex] > 0) {
          uint256 selectedReward = supPool[coinIndex][poolIndex];
          _mapRewards[_account].surprizeRewards[coinIndex] += selectedReward;
          supTotalSupply[coinIndex][poolIndex] -= 1;
          break;
        }
      }
    }
  }

  function _getRandomNumebr(uint256 seed, uint256 mod) view private returns(uint256) {
    if(mod == 0) {
      return 0;
    }
    return uint256(keccak256(abi.encode(block.timestamp, block.difficulty, block.coinbase, blockhash(block.number + 1), seed, block.number))) % mod;
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
    IWETH(address(weth)).deposit{value: wethAmount}();
    
    emit RewardSwapped(wethAmount);
  }

  function rewardsInfoOf(address _account) public view returns(UserInfo memory) {
      return _mapRewards[_account];
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