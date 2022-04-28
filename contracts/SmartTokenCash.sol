// SPDX-License-Identifier: MIT

/**
 * Smart Token Cash Token
 * @author Liu
 */

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import './interfaces/IUniswapRouter.sol';
import './interfaces/IUniswapFactory.sol';
import './interfaces/IUniswapPair.sol';
import './interfaces/IGoldenTreePool.sol';
import './interfaces/ISmartNobilityAchievement.sol';
import './interfaces/ISmartOtherAchievement.sol';
import './interfaces/ISmartComp.sol';
import './interfaces/ISmartTokenCash.sol';
import "hardhat/console.sol";

contract SmartTokenCash is ISmartTokenCash, ContextUpgradeable, UUPSUpgradeable, OwnableUpgradeable{
  using SafeMath for uint256;

  address public _uniswapV2BUSDPair;
  address public _operator;
  ISmartComp public comptroller;
  address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

  string private _name;
  string private _symbol;
  uint8 private _decimals;
  uint256 private _totalSupply;

  mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) private _allowances;

  modifier onlyOperator() {
    require(_operator == msg.sender || msg.sender == owner(), "SMTC: caller is not the operator");
    _;
  }

  function initialize(address _comp, address _questReward, address _dev, address _airdrop) public initializer {
      __Ownable_init();
      __SmartTokenCash_init_unchained(_comp, _questReward, _dev, _airdrop);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  function __SmartTokenCash_init_unchained(
    address _smartComp,
    address _questReward,
    address _dev,
    address _airdrop
  ) internal initializer {

    _name = "Smart Token Cash";
    _symbol = "SMTC";
    _decimals = 18;
    _totalSupply = 1000000 * 1e18;

    comptroller = ISmartComp(_smartComp);
    address goldenTreePoolAddress = address(comptroller.getGoldenTreePool());
    address nobilityAchievementAddress = address(comptroller.getSmartNobilityAchievement());
    address otherAchievementAddress = address(comptroller.getSmartOtherAchievement());
    _operator = msg.sender;

    IUniswapV2Router02 _uniswapV2Router = comptroller.getUniswapV2Router();
    IERC20 busdContract = comptroller.getBUSD();

    _uniswapV2BUSDPair = IUniswapV2Factory(_uniswapV2Router.factory())
        .createPair(address(this), address(busdContract));

    // quest reward mint.
    _balances[_questReward] = _totalSupply.div(1e5).mul(51576);
    // golden tree pool phase reward mint.
    _balances[goldenTreePoolAddress] = _totalSupply.div(1e5).mul(20132);
    // developer reward mint.
    _balances[_dev] = _totalSupply.div(10);
    // surprise reward mint.
    _balances[otherAchievementAddress] = _totalSupply.div(100).mul(9);
    // chest reward mint.
    _balances[nobilityAchievementAddress] = _totalSupply.div(1e5).mul(7692);
    // private sale bonus mint.
    _balances[_operator] = _totalSupply.div(100);
    // airdrop mint.
    _balances[_airdrop] = _totalSupply.div(1000).mul(5);
    // initial SMTC-BUSD liquidity mint.
    _balances[_operator] += _totalSupply.div(1000);
  }

  function name() external override view returns (string memory) {
      return _name;
  }

  function symbol() external override view returns (string memory) {
      return _symbol;
  }

  function decimals() external override view returns (uint8) {
      return _decimals;
  }

  function totalSupply() external override view returns (uint256) {
      return _totalSupply;
  }

  function balanceOf(address account) external override view returns (uint256) {
      return _balances[account];
  }

  function allowance(address owner, address spender) external override view returns (uint256) {
      return _allowances[owner][spender];
  }

  function getOwner() external override view returns (address) {
      return _operator;
  }

  function _approve(address owner, address spender, uint256 amount) internal {
    require(owner != address(0), 'SMT: approve from the zero address');
    require(spender != address(0), 'SMT: approve to the zero address');

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  function approve(address spender, uint256 amount) external override returns (bool) {
      _approve(_msgSender(), spender, amount);
      return true;
  }

  function transfer(address recipient, uint256 amount) external override returns (bool) {
      _transfer(_msgSender(), recipient, amount);
      return true;
  }

  function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
      _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
      return true;
  }

  function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
      _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, 'SMT: decreased allowance below zero'));
      return true;
  }

  function transferFrom(
      address sender, 
      address recipient, 
      uint256 amount
  ) public virtual override returns (bool) {
      _transfer(sender, recipient, amount);
      _approve(
          sender,
          _msgSender(),
          _allowances[sender][_msgSender()].sub(amount, 'SMT: transfer amount exceeds allowance')
      );        
      return true;
  }

  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal {
    require(from != address(0), "ERC20: transfer from the zero address");
    require(to != address(0), "ERC20: transfer to the zero address");

    uint256 fromBalance = _balances[from];
    require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
    unchecked {
        _balances[from] = fromBalance - amount;
    }
    _balances[to] += amount;

    emit Transfer(from, to, amount);
  }

  function burn(uint256 _amount) external override {
    _burn(msg.sender, _amount);
  }

  function _burn(address account, uint256 amount) internal {
    require(account != address(0), "ERC20: burn from the zero address");

    uint256 accountBalance = _balances[account];
    require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
    unchecked {
        _balances[account] = accountBalance - amount;
    }
    _totalSupply -= amount;

    emit Transfer(account, BURN_ADDRESS, amount);
  }
}
//////////////////////////////////////////////////////////