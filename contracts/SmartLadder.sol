// SPDX-License-Identifier: MIT

/**
 * Smart Ladder Contract
 * @author Liu
 */

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import './libs/TransferHelper.sol';

import './interfaces/ISmartComp.sol';
import './interfaces/ISmartLadder.sol';
import 'hardhat/console.sol';


contract SmartLadder is UUPSUpgradeable, OwnableUpgradeable, ISmartLadder {
  // using SafeMath for uint256;

  /// @dev percent divider
  uint256 constant public PERCENTS_DIVIDER = 10000;

  ISmartComp public comptroller;

  address public adminWallet;

  /// @dev Activities
  mapping(uint256 => Activity) public activities;

  uint256 totalActivities;

  /// @dev users // sponsor => users
  mapping(address => address[]) public users;
  /// @dev users // user => sponsor
  mapping(address => address) public sponsor;
  
  /// @dev Events
  event ActivityUpdated(uint256 id, Activity activity);
  event ActivityAdded(uint256 id, Activity activity);
  event ActivityEnabled(uint256 id, bool enable);

  event ReferralReward(address from, address sponsor, address token, uint256 amount, uint level);
  event AdminReferralReward(address from, address admin, address token, uint256 amount);
  

  function initialize(address _comp, address _admin) public initializer {
		__Ownable_init();
    __SmartLadder_init_unchained(_comp, _admin);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}


  function __SmartLadder_init_unchained(
      address _comp,
      address _admin
    )
        internal
        initializer
    {
        comptroller = ISmartComp(_comp);
        adminWallet = _admin;      
    }
    
  /**
   * Initialize Activities with default
   * 
   */
  function initActivities() external override onlyOwner {
    IERC20 smtToken = comptroller.getSMT();

    _updateActivity(1,    "buytax",      [5000, 500, 500, 750, 750, 1250, 1250], address(smtToken),  true,  true);
    _updateActivity(2,    "farmtax",     [5500, 250, 250, 750, 750, 1250, 1250], address(smtToken),  true,  true);
    _updateActivity(3,    "smartliving", [5000, 500, 500, 750, 750, 1250, 1250], address(smtToken),  true,  true);
    _updateActivity(4,    "ecosystem",   [5000, 500, 500, 750, 750, 1250, 1250], address(smtToken),  true,  true);

    totalActivities = 4;
  }


  /**
    * @notice Sets a new comptroller
    * @dev Admin function to set a new comptroller
    */
  function setComptroller(ISmartComp newComptroller) external onlyOwner {
    // Ensure invoke comptroller.isComptroller() returns true
    require(newComptroller.isComptroller(), "marker method returned false");

    // Set comptroller to newComptroller
    comptroller = newComptroller;
  }

  /**
   * Update Admin wallet
   */
  function updateAdminWallet(
    address _address
  ) external onlyOwner {
    require(_address != address(0x0), "admin wallet can't be zero address");
    adminWallet = _address;
  }

  /**
   * return sponsor array
   * @param _sponsor : user to register
   */
  function usersOf(address _sponsor) 
    external override view returns(address[] memory) 
  {
    return users[_sponsor];
  }

  function sponsorOf(address _user)
    external override view returns (address) 
  {
    return sponsor[_user];
  }

  /**
   * is registered Referral
   * @param _user : user to register
   * @param _sponsor : address of sponsor
   */
  function isRegistered(address _user, address _sponsor) 
    public view returns(bool) 
  {
    address[] memory userAddresses = users[_sponsor];
    uint i=0;    
    for(i=0; i<userAddresses.length; i++)
      if(userAddresses[i] == _user) break;
    if(i < userAddresses.length) return true;
    return false;
  }

  /**
   * register Referral
   * @param _user : user to register
   * @param _sponsor : address of sponsor
   */
  function registerSponsor(
    address _user,
    address _sponsor
  ) public override {
    require(msg.sender == address(comptroller.getSmartArmy()) || msg.sender == owner(), "SmartLadder#registerSponsor: only SmartArmy or owner");
    require(!isRegistered(_user, _sponsor), "SmartLadder#registerSponsor: already registered");
    users[_sponsor].push(_user);
    sponsor[_user] = _sponsor;
  }

  /**
   * add new Activity
   */
  function addActivity(
    string memory _name,
    uint16[7] memory _share,
    address _token
  ) 
    public 
    onlyOwner 
  {
    totalActivities += 1;
    Activity storage _activity = activities[totalActivities];
    require(!_activity.isValid, "SmartLadder#addActivity: already exist");

    uint16 _sumPercent = 0;
    for(uint i = 0; i < 7; i++) {
      _sumPercent = _sumPercent + _share[i];
    }
    require(_sumPercent == PERCENTS_DIVIDER, "SmartLadder#addActivity: invalid share");
    
    _activity.name = _name;
    _activity.token = _token;
    _activity.share = _share;
    _activity.enabled = true;
    _activity.isValid = true;
    
    emit ActivityAdded(totalActivities, _activity);
  } 

  /**
   * Update Activity Share percentage
   */
  function updateActivityShare(
    uint256 _id, 
    uint16[7] memory _share
  ) public onlyOwner {
    Activity storage _activity = activities[_id];
    require(_activity.isValid, "SmartLadder#updateActivityShare: invalid activity");

    uint16 _sumPercent = 0;
    for(uint i = 0; i < 7; i++) {
      _sumPercent = _sumPercent + _share[i];
    }
    require(_sumPercent == PERCENTS_DIVIDER, "SmartLadder#updateActivityShare: invalid share");
    
    _activity.share = _share;
    
    emit ActivityUpdated(_id, _activity);
  }

  /**
   * Enable or Disable Activity
   */
  function enableActivity(
    uint256 _id,
    bool enable
  ) public onlyOwner {
    Activity storage _activity = activities[_id];
    require(_activity.isValid, "SmartLadder#enableActivity: invalid activity");

    _activity.enabled = enable;

    emit ActivityEnabled(_id, enable);
  }

  /**
   * Update Activity Information
   */
  function _updateActivity(
    uint256 _id, 
    string memory _name,
    uint16[7] memory _share,
    address _token,
    bool _enabled,
    bool _isValid
  ) 
    private 
  {
    Activity storage _activity = activities[_id];
    _activity.name  = _name;
    _activity.token = _token;
    _activity.enabled = _enabled;
    _activity.isValid = _isValid;

    updateActivityShare(_id, _share);
  } 

  /**
   * Distribute Tax SMT to referrals
   * @param account: from address
   */
  function distributeTax(
    uint256 id,
    address account
  ) 
    public 
    override
  {
    Activity memory _activity = activities[id];
    require(_activity.isValid && _activity.enabled, "SmartLadder#distributeTax: invalid activity");

    _distribute(id, account);
  }

  /**
   * Distribute Buy Tax SMT to referrals
   * @param account: the address to buy on dex
   */
  function distributeBuyTax(
    address account
  ) 
    public 
    override
  {
    _distribute(1, account);
  }

  /**
   * Distribute Farming Tax SMT to referrals
   * @param account:  from address
   */
  function distributeFarmingTax(
    address account
  ) 
    public 
    override
  {
    _distribute(2, account);
  }

  /**
   * Distribute Smart Living Tax SMT to referrals
   * @param account:  from address
   */
  function distributeSmartLivingTax(
    address account
  ) 
    public 
    override
  {
    _distribute(3, account);
  }

  /**
   * Distribute Ecosystem Tax SMT to referrals
   * @param account:  from address
   */
  function distributeEcosystemTax(
    address account
  ) 
    public 
    override
  {
    _distribute(4, account);
  }

  /**
   * Private rewards to referrals 
   */
  function _distribute(
    uint256 id,
    address from
  ) 
    internal 
  {
    Activity storage _activity = activities[id];
    address token = _activity.token;
    uint256 amount = IERC20(token).balanceOf(address(this));
    if(amount == 0) return;
    if(!_activity.isValid || !_activity.enabled || sponsor[from] == address(0x0)) {
      // if activity is not valid or is stopped now, all token to admin wallet
      TransferHelper.safeTransferTokenOrETH(token, adminWallet, amount);
      emit AdminReferralReward(from, adminWallet, token, amount);
    } else {
      uint256 paid = 0;
      address ref = from;
      for(uint i = 0 ; i < _activity.share.length; i++) {
        uint16 percent = _activity.share[i];
        ref = sponsor[ref];
        uint256 ladderLevel = comptroller.getSmartArmy().licenseLevelOf(ref);
        if(percent > 0 && ref != address(0x0) && ladderLevel > 0) {
          uint256 shareAmount = amount * percent / PERCENTS_DIVIDER;
          TransferHelper.safeTransferTokenOrETH(token, ref, shareAmount);
          paid += shareAmount;
          emit ReferralReward(from, ref, token, shareAmount, i+1);
        }
      }
      if(amount > paid) {
        uint256 remain = amount - paid;
        TransferHelper.safeTransferTokenOrETH(token, adminWallet, remain);
        emit AdminReferralReward(from, adminWallet, token, remain);
      }
    }

    _activity.totalDistributed = _activity.totalDistributed + amount;
  }

  
  /**
   * get Activity Information from id
   */
  function activity(uint256 id) 
    public 
    view
    override
    returns(Activity memory) 
  {
      return activities[id];
  }

}