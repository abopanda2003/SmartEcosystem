// SPDX-License-Identifier: MIT

/**
 * License Based Service Contract
 * @author Liu
 */

pragma solidity 0.8.4;


import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./interfaces/ISmartComp.sol";
import "./SMTBridge.sol";
import "hardhat/console.sol";

contract SmartComp is UUPSUpgradeable, OwnableUpgradeable, ISmartComp {

  ISmartArmy public smartArmy;
  ISmartLadder public smartLadder;
  ISmartFarm public smartFarm;
  IGoldenTreePool public goldenTreePool;
  ISmartAchievement public smartAchievement;
  ISmartTokenCash public smtcToken;
  address public smartBridge;

  IUniswapV2Router02 public uniswapV2Router;

  IERC20 public smtToken;
  IERC20 public busdToken;
  
  /// @notice Emitted when smart ladder is changed
  event NewSmartLadder(ISmartLadder oldSmartLadder, ISmartLadder newSmartLadder);

  /// @notice Emitted when smart army is changed
  event NewSmartArmy(ISmartArmy oldSmartArmy, ISmartArmy newSmartArmy);

  /// @notice Emitted when smart farm is changed
  event NewSmartFarm(ISmartFarm oldSmartFarm, ISmartFarm newSmartFarm);

  /// @notice Emitted when golden tree pool is changed
  event NewGoldenTreePool(IGoldenTreePool oldPool, IGoldenTreePool newPool);

  /// @notice Emitted when smart achievement system is changed
  event NewSmartAchievement(ISmartAchievement oldAchievement, ISmartAchievement newAchievement);


  function initialize(address _router, address _busd) public initializer {
		__Ownable_init();
    __SmartComp_init_unchained(_router, _busd);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}


  function __SmartComp_init_unchained(address _router, address _busd)
    internal    
    initializer
  {
    busdToken = IERC20(_busd);  // Testnet
    // Pancake V2 router
    // IUniswapV2Router02 _uniswapRouter = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3); 
    IUniswapV2Router02 _uniswapRouter = IUniswapV2Router02(_router);
    uniswapV2Router = _uniswapRouter;
  }

  /*** View Functions ***/
  function isComptroller() external override pure returns(bool) {
    return true;
  }
  
  function getSMT() external override view returns(IERC20) {
    return smtToken;
  }

  function getSMTC() external override view returns(ISmartTokenCash) {
    return smtcToken;
  }

  function getBUSD() external override view returns(IERC20) {
    return busdToken;
  }

  function getUniswapV2Factory() external override view returns(address) {
    return uniswapV2Router.factory();
  }

  function getWBNB() external override view returns(IERC20) {
    return IERC20(uniswapV2Router.WETH());
  }

  function getUniswapV2Router() external override view returns(IUniswapV2Router02) {
    return uniswapV2Router;
  }

  function getSmartArmy() external override view returns(ISmartArmy) {
    return smartArmy;
  }

  function getSmartLadder() external override view returns(ISmartLadder) {
    return smartLadder;
  }

  function getSmartFarm() external override view returns(ISmartFarm) {
    return smartFarm;
  }

  function getGoldenTreePool() external override view returns(IGoldenTreePool) {
    return goldenTreePool;
  }

  function getSmartAchievement() external override view returns(ISmartAchievement) {
    return smartAchievement;
  }

  function getSmartBridge() external override view returns(address) {
    return smartBridge;
  }

  /*** Admin Functions ***/

  /**
    * @notice Sets a new Uniswap Router 02 address contract for the comptroller
    * 
    */
  function setUniswapRouter(address _address) external onlyOwner {
      uniswapV2Router = IUniswapV2Router02(_address);
  }

  /**
    * @notice Sets a new BUSD contract for the comptroller
    * 
    */
  function setBUSD(address _address) external onlyOwner {
      busdToken = IERC20(_address);
  }

  /**
    * @notice Sets a new BUSD contract for the comptroller
    * 
    */
  function setSMTC(address _address) external onlyOwner {
      smtcToken = ISmartTokenCash(_address);
  }

  /**
    * @notice Sets a new BUSD contract for the comptroller
    * 
    */
  function setSMT(address _address) external onlyOwner {
      smtToken = IERC20(_address);
  }

  /**
    * @notice Sets a new BUSD contract for the comptroller
    * 
    */
  function setSmartBridge(address _address) external onlyOwner {
      require(_address != address(0x0), "input address can't be not zero address");
      smartBridge = _address;
  }

  /**
    * @notice Sets a new smart ladder contract for the comptroller
    * 
    */
  function setSmartLadder(address _address) external onlyOwner {
    // Track the old for the comptroller
    ISmartLadder oldSmartLadder = smartLadder;
    smartLadder = ISmartLadder(_address);
    emit NewSmartLadder(oldSmartLadder, smartLadder);
  }

  /**
    * @notice Sets a new smart army contract for the comptroller
    * 
    */
  function setSmartArmy(address _address) external onlyOwner {
    // Track the old for the comptroller
    ISmartArmy oldSmartArmy = smartArmy;
    smartArmy = ISmartArmy(_address);
    emit NewSmartArmy(oldSmartArmy, smartArmy);
  } 

  /**
    * @notice Sets a new smart farm contract for the comptroller
    * 
    */
  function setSmartFarm(address _address) external onlyOwner {
    // Track the old for the comptroller
    ISmartFarm oldSmartFarm = smartFarm;
    smartFarm = ISmartFarm(_address);
    emit NewSmartFarm(oldSmartFarm, smartFarm);
  }

  /**
    * @notice Sets a new golden tree pool contract for the comptroller
    * 
    */
  function setGoldenTreePool(address _address) external onlyOwner {
    // Track the old for the comptroller
    IGoldenTreePool oldGoldenTreePool = goldenTreePool;
    goldenTreePool = IGoldenTreePool(_address);
    emit NewGoldenTreePool(oldGoldenTreePool, goldenTreePool);
  }

  /**
    * @notice Sets a new achievement system contract for the comptroller
    */
  function setSmartAchievement(address _address) external onlyOwner {
    // Track the old for the comptroller
    ISmartAchievement oldAchievement = smartAchievement;
    smartAchievement = ISmartAchievement(_address);
    emit NewSmartAchievement(oldAchievement, smartAchievement);
  }
}