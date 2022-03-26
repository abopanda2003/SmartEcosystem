// SPDX-License-Identifier: MIT

/**
 * Smart Army License Contract
 * @author Liu
 */

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import './libs/TransferHelper.sol';

import './interfaces/ISmartComp.sol';
import './interfaces/ISmartArmy.sol';
import './interfaces/ISmartLadder.sol';
import './interfaces/IUniswapRouter.sol';
import './interfaces/IUniswapFactory.sol';
import 'hardhat/console.sol';

contract SmartArmy is UUPSUpgradeable, OwnableUpgradeable, ISmartArmy {
  // using SafeMath for uint256;
  // using SafeERC20 for IERC20;

  uint256 public constant LICENSE_EXPIRE = 12 * 30 * 24 * 3600; // 12 months

  ISmartComp public comptroller;
  
  FeeInfo public feeInfo;

  /// @dev License Types
  mapping(uint256 => LicenseType) public licenseTypes;

  uint256 totalLicenses;
  uint256 licenseIndex;
  /// @dev User License Mapping  licenseId => License
  mapping(uint256 => UserLicense) public licenses;
  /// @dev User address => licenseId
  mapping(address => uint256) public userLicenses;

  /// @dev User Personal Information
  mapping(address => UserPersonal) public userInfo;


  /// @dev Events
  event LicenseTypeCreated(uint256 level, LicenseType _type);
  event LicenseTypeUpdated(uint256 level, LicenseType _type);
  event RegisterLicense(address account, UserLicense license);
  event ActivatedLicense(address account, UserLicense license);
  
  event LiquidateLicense(address account, UserLicense license);
  event ExtendLicense(address account, UserLicense license);
  event TransferLicense(address account, UserLicense license);


  function initialize(address _comp) public initializer {
		__Ownable_init();
    __SmartArmy_init_unchained(_comp);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}


  function __SmartArmy_init_unchained(address _comp)
    internal
    initializer
  {
      comptroller = ISmartComp(_comp);

      feeInfo = FeeInfo({
        penaltyFeePercent: 10,
        extendFeeBNB: 10 ** 16, // 0.01 BNB
        feeAddress: 0xc2A79DdAF7e95C141C20aa1B10F3411540562FF7
      });

      _initLicenseTypes();
  }
    
  /**
   * Initialize License types with default
   * 
   */
  function _initLicenseTypes() internal {
    licenseIndex = 1;
    createLicense("Trial",       100 * 10 ** 18,    1, true);
    createLicense("Opportunist", 1_000 * 10 ** 18,  3, true);
    createLicense("Runner",      5_000 * 10 ** 18,  5, true);
    createLicense("Visionary",   10_000 * 10 ** 18, 7, true);
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
   * Update Fee Information
   */
  function updateFeeInfo(
    uint256 _penaltyFeePercent,      // Stop License LP fee percent
    uint256 _extendFeeBNB,       // Extend Fee LP fee percent
    address _feeAddress
  ) external onlyOwner {
    require(_penaltyFeePercent < 1000, "SmartArmy#updateFeeInfo: Too big penalty fee");
    
    feeInfo.penaltyFeePercent = _penaltyFeePercent;
    feeInfo.extendFeeBNB = _extendFeeBNB;
    feeInfo.feeAddress = _feeAddress;
  }
  
  function fetchAllLicenses() 
    public view returns(LicenseType[] memory)
  {
    LicenseType[] memory allLicenses = new LicenseType[](countOfLicenses());

    for(uint i=1; i<licenseIndex; i++)
      allLicenses[i-1] = licenseTypes[i];

    return allLicenses;
  }

  function countOfLicenses() 
    public view returns(uint256) 
  {
    return licenseIndex - 1;
  }

  /**
   * Create License type
   */
  function createLicense(
    string memory _name,
    uint256 _price,
    uint256 _ladderLevel,
    bool _isValid
  ) public onlyOwner {
    require(_price > 0, "SmartArmy#updateLicenseType: Invalid Price");

    LicenseType storage _type = licenseTypes[licenseIndex];
    _type.level = licenseIndex;
    _type.name  = _name;
    _type.price = _price;
    _type.ladderLevel = _ladderLevel;
    _type.duration = LICENSE_EXPIRE;
    _type.isValid = _isValid;
    emit LicenseTypeCreated(licenseIndex, _type);
    licenseIndex += 1;
  }

  /**
   * Update License type
   */
  function updateLicenseType(
    uint256 _level, 
    string memory _name,
    uint256 _price,
    uint256 _ladderLevel,
    string memory _tokenUri,
    bool _isValid
  ) 
    public 
    onlyOwner 
  {    
    require(_price > 0, "SmartArmy#updateLicenseType: Invalid Price");

    LicenseType storage _type = licenseTypes[_level];
    _type.level = _level;
    _type.name  = _name;
    _type.price = _price;
    _type.ladderLevel = _ladderLevel;
    _type.duration = LICENSE_EXPIRE;
    _type.isValid = _isValid;

    emit LicenseTypeUpdated(_level, _type);
  } 

  /**
   * Update License type
   */
  function updateLicenseTypePrice(
    uint256 _level, 
    uint256 _price
  ) public onlyOwner {
    require(_price > 0, "SmartArmy#updateLicenseType: Invalid Price");

    LicenseType storage _type = licenseTypes[_level];
    _type.price = _price;

    emit LicenseTypeUpdated(_level, _type);
  }

  /**
   * Start License
   * 
   */
  function registerLicense(
    uint256 _level,
    address _sponsor,
    string memory _username,
    string memory _telegram,
    string memory _tokenUri
  ) external {
    require(licenseOf(msg.sender).status == LicenseStatus.None
      || licenseOf(msg.sender).status == LicenseStatus.Expired, "SmartArmy#startLicense: already started");

    uint256 newLicenseId = totalLicenses + 1;

    LicenseType memory _type = licenseTypes[_level];
    require(_type.isValid, "SmartArmy#startLicense: Invalid License Level");

    UserLicense storage license = licenses[newLicenseId];
    license.owner = _msgSender();
    license.level = _level;
    license.startAt = block.timestamp;
    license.expireAt = block.timestamp + LICENSE_EXPIRE;
    license.lpLocked = 0;
    license.tokenUri = _tokenUri;
    license.status  = LicenseStatus.Pending;

    userLicenses[_msgSender()] = newLicenseId;

    UserPersonal storage info = userInfo[_msgSender()];
    info.username = _username;
    info.telegram = _telegram;

    ISmartLadder smartLadder = comptroller.getSmartLadder();
    address prevSponsor = smartLadder.sponsorOf(msg.sender);
    if(prevSponsor == address(0x0) && _sponsor != address(0x0)) {
      smartLadder.registerSponsor(msg.sender, _sponsor);
      info.sponsor  = _sponsor;
    } else {
      info.sponsor  = prevSponsor == address(0x0) ? _sponsor : prevSponsor;
    }

    emit RegisterLicense(_msgSender(), license);
  }

  /**
   * Activate License
   * 
   */
  function activateLicense() external {
    UserLicense storage license = licenses[userLicenses[msg.sender]];
    require(license.status == LicenseStatus.Pending, "SmartArmy#activateLicense: not registered");

    LicenseType memory _type = licenseTypes[license.level];
    require(_type.isValid, "SmartArmy#activateLicense: Invalid License Level");

    // Transfer SMT token for License type to this contract
    uint256 smtAmount = _type.price;
    uint amount = _tranferSmtToContract(_msgSender(), smtAmount);
    uint256 liquidity = comptroller.getSmartFarm().stakeSMT(_msgSender(), amount);
    require(liquidity > 0, "SmartArmy#activateLicense: failed to add liquidity");

    license.activeAt = block.timestamp;
    license.lpLocked = liquidity;
    license.status  = LicenseStatus.Active;

    emit ActivatedLicense(_msgSender(), license);
  }

  /**
   * Liquidate License
   *  
   */
  function liquidateLicense() external {
    uint256 userLicenseId = userLicenses[_msgSender()];
    UserLicense storage license = licenses[userLicenseId];
    require(license.status == LicenseStatus.Active, "SmartArmy#liquidateLicense: no license yet");
    require(license.expireAt <= block.timestamp, "SmartArmy#liquidateLicense: still active");

    uint256 smtAmount = comptroller.getSmartFarm().withdrawSMT(_msgSender(), license.lpLocked);
    require(smtAmount > 0, "SmartArmy#liquidateLicense: failed to refund SMT");

    _tranferSmtToUser(_msgSender(), smtAmount);
    
    //remove license
    license.owner = address(0x0);
    license.lpLocked = 0;
    license.status = LicenseStatus.Expired;

    userLicenses[_msgSender()] = 0;

    emit LiquidateLicense(_msgSender(), license);
  }

  /**
   * Extend License
   *  
   */
  function extendLicense() external payable {
    uint256 userLicenseId = userLicenses[_msgSender()];
    UserLicense storage license = licenses[userLicenseId];

    require(license.status == LicenseStatus.Active, "SmartArmy#extendLicense: no license yet");
    require(license.expireAt <= block.timestamp, "SmartArmy#extendLicense: still active");

    // Transfer Extend fee to fee address
    TransferHelper.safeTransferETH(feeInfo.feeAddress, feeInfo.extendFeeBNB);

    license.activeAt = block.timestamp;
    license.startAt = block.timestamp;
    license.expireAt = block.timestamp + LICENSE_EXPIRE;
    
    emit ExtendLicense(_msgSender(), license);
  }

  /**
   * Transfer smt token to contract.
   * Swap half as BUSD, 
   * Add Liquidity => LP token Lock
   */
  function _tranferSmtToContract(address _from, uint256 _amount) 
    private 
    returns(uint) 
  {
    IERC20 smtToken = comptroller.getSMT();
    // Transfer SMT token from user to contract
    uint256 beforeBalance = smtToken.balanceOf(address(this));
    smtToken.transferFrom(_from, address(this), _amount);
    uint256 amount = smtToken.balanceOf(address(this)) - beforeBalance;
    require(amount > 0, "SmartArmy#transferSmtToContract: faild to transfer SMT token");

    smtToken.approve(address(comptroller.getSmartFarm()), amount);

    return amount;
  }

  /**
   * Transfer smt token to user.
   */
  function _tranferSmtToUser(address _to, uint256 _amount) private returns(uint) {
    if(_amount == 0) {
      return 0;
    }
    IERC20 smtToken = comptroller.getSMT();
    
    // Tranfer Penalty Fee to fee address
    uint256 feeAmount = _amount * feeInfo.penaltyFeePercent / 1000;

    IERC20(smtToken).transfer(feeInfo.feeAddress, feeAmount);

    // Transfer SMT token to user
    IERC20(smtToken).transfer(_to, _amount - feeAmount);
    
    return _amount;
  }

  /**
   * Get License of Account
   */
  function licenseOf(address account) 
    public 
    view
    override
    returns(UserLicense memory) 
  {
      return licenses[userLicenses[account]];
  }

  /**
   * Get License ID of Account
   */
  function licenseIdOf(address account) 
    public 
    view
    override
    returns(uint256)
  {
      return userLicenses[account];
  }

  /**
   * Get License Type with level
   */
  function licenseTypeOf(uint256 level) 
    public 
    view
    override
    returns(LicenseType memory)
  {
    return licenseTypes[level];
  }

  /**
   * Get Locked SMT-BUSD LP token amount on Farming contract
   */
  function lockedLPOf(address account) 
    public view override returns(uint256) 
  {
    return licenseOf(account).lpLocked;
  }

  /**
   * Get Level of License Type
   */
  function licenseLevelOf(address account) 
    public 
    view
    override
    returns(uint256) 
  {
    if(isActiveLicense(account)) {
      UserLicense memory license = licenseOf(account);
      LicenseType memory _type = licenseTypes[license.level];

      return _type.ladderLevel;
    } else {
      return 0;
    }
  }

  /**
   * Check if license is Active status and not expired
   */
  function isActiveLicense(address account) 
    public 
    view 
    override
    returns(bool)
  {
      UserLicense memory license = licenseOf(account);
      return license.status == LicenseStatus.Active && license.expireAt > block.timestamp;
  }

  /**
   * Get License active duration from `from` to `to`
   */
  function licenseActiveDuration(
    address account,
    uint256 from,
    uint256 to
  )
    public 
    view
    override
    returns (uint256, uint256) 
  {
    UserLicense memory license = licenseOf(account);

    uint256 start = license.activeAt >= from ? license.activeAt : from;
    uint256 end = license.expireAt < to ? license.expireAt : to;

    if(start >= end) {
      // there is no activation duration
      return (0, 0);
    }

    return (start, end);
  }

  /**
   * Check if enabled intermediary
   */
  function isEnabledIntermediary(address account) 
    public 
    view 
    override
    returns(bool)
  {
      UserLicense memory license = licenseOf(account);
      return (license.status == LicenseStatus.Pending && block.timestamp > license.startAt + 12 * 3600)
        || license.status == LicenseStatus.Active;
  }

}