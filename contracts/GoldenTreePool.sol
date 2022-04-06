// SPDX-License-Identifier: MIT

/**
 * Golden Tree Pool Contract (SMTC-BUSD pool)
 * @author Liu
 */

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./interfaces/IUniswapRouter.sol";
import "./interfaces/ISmartTokenCash.sol";
import "./interfaces/ISmartComp.sol";
import "./interfaces/IGoldenTreePool.sol";
import "./interfaces/ISmartAchievement.sol";
import "./interfaces/ISmartLadder.sol";
import "./interfaces/ISmartArmy.sol";
import "hardhat/console.sol";

contract GoldenTreePool is UUPSUpgradeable, OwnableUpgradeable, IGoldenTreePool {
  // using SafeERC20 for IERC20;
  // using SafeMath for uint256;
  // using EnumerableSet for EnumerableSet.AddressSet;

  /// @dev Token Addresses
  ISmartComp public comptroller;

  bool public swapEnabled;
  uint256 public limitPerSwap;

  /// @dev Total BUSD rewards
  uint256 public totalRevenue;
  /// @dev Total Swapped BUSD
  uint256 public totalSwapped;
  /// @dev Total Burned SMTC
  uint256 public totalBurned;
  /// @dev Current phase of golden tree
  uint256 public currentPhase;

  /// @dev Growth Balance Mapping
  /// user address => Growth Balance
  mapping(address => uint256) public growthBalances;

  /// @dev Growth Balance share percentage
  uint16[8] public growthShare;

  /// @dev phase info
  uint256[10] public phaseRewards;
  uint256[10] public phaseThresold;

  address[] _rewardsDistributors;

  // EnumerableSet.AddressSet private _rewardsDistributors;
  // events 
  event RewardAdded(uint256 amount, address account);
  event RewardSwapped(uint256 smtAmount, uint256 busdAmount);
  event Growth(uint256 amount, address account);
  event ReferralGrowth(uint256 amount, address account, address referral, uint level);
  event UpgradeTreePhase(uint256 phaseNumber);

  function initialize(address _comp) public initializer {
		__Ownable_init();

    comptroller = ISmartComp(_comp);

    swapEnabled = true;
    limitPerSwap = 1000 * 1e18;
    
    growthShare = [uint16(6500), 500, 500, 500, 500, 500, 500, 500];
    phaseRewards = [uint256(0), 1e18, 1e19, 5e19, 1e20, 5e20, 1e21, 5e21, 1e22, 84e21];
    phaseThresold = [uint256(1), 19, 271, 999, 5786, 38547, 774503, 1855700, 33579113, 63745062];

    addValue(address(this));
    addValue(msg.sender);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  /**
    * @notice Sets a new comptroller
    * @dev Admin function to set a new comptroller
    */
  function setComptroller(ISmartComp newComptroller) external onlyOwner {
    require(newComptroller.isComptroller(), "marker method returned false");
    comptroller = newComptroller;
  }  

  /**
   * @dev Add rewards distributor
   * @param _address Address of Reward Distributor
   */
  function addDistributor(address _address) external onlyOwner {
    addValue(_address);
  }

  /**
   * @dev Remove rewards distributor
   * @param _address Address of Reward Distributor
   */
  function removeDistributor(address _address) external onlyOwner {
    removeByValue(_address);
  }

  /**
   * @dev Set Enable or Disable swap and distribute
   * @param _enabled boolean
   */
  function setSwapEnabled(bool _enabled) external onlyOwner {
    swapEnabled = _enabled;
  }

  /**
   * @dev max limitation of smt amount to swap per once
   * @param _amount amount
   */
  function setLimitPerSwap(uint256 _amount) external onlyOwner {
    limitPerSwap = _amount;
  }
  
  /**
   * Update Growth token distribution percent
   */
  function updateGrowthShare(
    uint16[8] memory _share
  ) 
    external 
    onlyOwner 
  {
    uint16 _sumPercent = 0;
    for(uint i = 0; i < 8; i++) {
      _sumPercent = _sumPercent + _share[i];
    }
    require(_sumPercent == 10_000, "GoldenTreePool#updateGrowthShare: invalid share");

    growthShare = _share;
  }

  /**
   * Sell SMTC token with threshold price
   * Received SMTC token will be burnned
   * 
   */
  function sellSmtc(uint256 amount) external {
    require(amount > 0, "GoldenTreePool#buySmtc: Invalid zero amount");
    
    IERC20 busdToken = comptroller.getBUSD();
    ISmartTokenCash smtcToken = comptroller.getSMTC();
    uint256 smtcBalance = smtcToken.balanceOf(address(this));
    uint256 busdBalance = busdToken.balanceOf(address(this));
    require(amount <= smtcBalance, "GoldenTreePool#buySmtc: insufficient SMTC balance");
    require(busdBalance > 0, "GoldenTreePool#buySmtc: insufficient BUSD balance");

    smtcToken.transferFrom(msg.sender, address(this), amount);
    smtcToken.burn(amount);

    uint256 busdAmount = amount * thresholdPrice() / 1e18;
    IERC20(busdToken).transfer(msg.sender, busdAmount);

    totalSwapped += busdAmount;
  }

  /**
   * Swap SMT token to BUSD
   * This function should be called from anyone
   */
  function swapDistribute() external override onlySmartMember {
    IERC20 busdToken = comptroller.getBUSD();
    IERC20 smtToken = comptroller.getSMT();

    uint256 smtBalance = smtToken.balanceOf(address(this));
    require(smtBalance > 0, "GoldenTreePool#swapDistribute: insufficient SMT balance");

    if(!swapEnabled || smtBalance <= limitPerSwap) {
      return;
    }

    address[] memory busdpath = new address[](2);
    busdpath[0] = address(smtToken);
    busdpath[1] = address(busdToken);

    IUniswapV2Router02 _uniswapV2Router = comptroller.getUniswapV2Router();

    smtToken.approve(address(_uniswapV2Router), smtBalance);

    uint256 beforeBalance = busdToken.balanceOf(address(this));
    _uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
        smtBalance,
        0,
        busdpath,
        address(this),
        block.timestamp + 3600
    );
    uint256 amount = busdToken.balanceOf(address(this)) - beforeBalance;

    emit RewardSwapped(smtBalance, amount);
  }

  function distributePhaseReward(uint256 phase) internal {
    uint256 smtcRewards = phaseRewards[phase-1];
    ISmartAchievement ach = comptroller.getSmartAchievement();
    ach.distributeToNobleLeaders(smtcRewards);
    ach.distributeToFarmers(smtcRewards);
  }

  /**
   * notify rewards to golden tree pool from smt token
   * This function should be called after transfer BUSD to this pool or
   * Swapped.
   */
  function notifyReward(uint256 amount, address account) 
    external 
    override 
    onlyRewardsDistributor 
  {

    if(amount == 0) {
      return;
    }

    IERC20 busdToken = comptroller.getBUSD();
    IERC20 smtToken = comptroller.getSMT();

    address[] memory busdpath = new address[](2);
    busdpath[0] = address(smtToken);
    busdpath[1] = address(busdToken);

    IUniswapV2Router02 _uniswapV2Router = comptroller.getUniswapV2Router();
    uint256 busdAmount = _uniswapV2Router.getAmountsOut(amount, busdpath)[1];



    // Add growth balance for from account
    // distribute growth token to referral
    address ref = account;
    ISmartLadder smartLadder = comptroller.getSmartLadder();
    ISmartArmy smartArmy = comptroller.getSmartArmy();

    for(uint i = 0 ; i < growthShare.length; i++) {
      uint16 percent = growthShare[i];
      if(percent > 0 && ref != address(0x0)) {
        uint256 shareAmount = busdAmount * percent / 10_000;      
        if(i == 0) {
          increaseGrowth(ref, shareAmount);
          emit Growth(shareAmount, ref);
        } else {
          uint256 ladderLevel = smartArmy.licenseLevelOf(ref);
          if(ladderLevel >= i) {
            increaseGrowth(ref, shareAmount);
            emit ReferralGrowth(shareAmount, ref, account, i);
          }
        }
      }
      ref = smartLadder.sponsorOf(ref);
    }

    totalRevenue += busdAmount;
    uint256 newPhase = currentPhaseOfGoldenTree();
    if(currentPhase < newPhase){
      distributePhaseReward(newPhase);
      currentPhase = newPhase;
      emit UpgradeTreePhase(newPhase);
    }
    emit RewardAdded(amount, account);
  }

  /**
   * Increase Growth Token
   */
  function increaseGrowth(address account, uint256 amount) internal {
    uint256 old = growthBalanceOf(account);
    growthBalances[account] += amount;
    
    ISmartAchievement ach = comptroller.getSmartAchievement();
    ach.notifyGrowth(account, old, growthBalanceOf(account));
  }
  
  /**
   * Get Total Supply of SMTC token
   */
  function smtcTotalSupply() public view returns(uint256) {
    ISmartTokenCash smtcToken = comptroller.getSMTC();
    return smtcToken.totalSupply();
  }

  /**
   * Get Threshold Price 
   * (Stored BUSD balance) / (SMTC total supply) * 1e18
   */
  function thresholdPrice() public view returns(uint256) {
    uint256 bal = comptroller.getBUSD().balanceOf(address(this));
    return bal * 1e18 / smtcTotalSupply();
  }

  /**
   * Get Groth Point
   * (Growth balance) / (1000 BUSD)
   */
  function growthBalanceOf(address account) public view returns(uint256) {
    return growthBalances[account] / 1000;
  }

  function contributionOf(address account) public view returns(uint256) {    
    return growthBalanceOf(account) * 100 / currentTotalGrowth();
  }

  function currentTotalGrowth() public view returns(uint256) {
    return totalRevenue / 1000;
  }

  function currentPhaseOfGoldenTree() public view returns(uint256) {
    uint256 totalGrowth = currentTotalGrowth() / 1e18;
    if(totalGrowth < phaseThresold[0]) return 0;

    uint256 i;
    for(i=0; i<phaseThresold.length; i++){
      if(totalGrowth < phaseThresold[i]) break;
    }
    if(i == phaseThresold.length) return i;
    return i+1;
  }

  function indexOf(address value) public view returns(uint) {
    uint i = 0;
    while (_rewardsDistributors[i] != value) {
        i++;
    }
    return i;
  }

  function contain(address value) public view returns(bool) {
      uint i = 0;
      for(i=0; i<_rewardsDistributors.length; i++)
          if(_rewardsDistributors[i] == value) break;
      
      if(i < _rewardsDistributors.length) return true;
      return false;
  }

  function addValue(address value) internal {
      _rewardsDistributors.push(value);
  }

  function removeByValue(address value) internal {
      require(_rewardsDistributors.length > 0, "The array length is zero now.");
      uint i = indexOf(value);
      removeByIndex(i);
  }

  function removeByIndex(uint i) internal {
      require(_rewardsDistributors.length > 0, "The array length is zero now.");
      while (i<_rewardsDistributors.length-1) {
          _rewardsDistributors[i] = _rewardsDistributors[i+1];
          i++;
      }
      _rewardsDistributors.pop();
  }

  function getRewardsDistributor() public view returns(address[] memory) {
      return _rewardsDistributors;
  }

  modifier onlyRewardsDistributor() {
    require(
      contain(msg.sender)
      || msg.sender == (address)(comptroller.getSMT())
      || msg.sender == (address)(comptroller.getSmartFarm()),
      "GoldenTreePool: only reward distributors"
    );
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
} 