// SPDX-License-Identifier: MIT

/**
 * Smart Token
 * @author Liu
 */

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import './libs/IBEP20.sol';
import './libs/TransferHelper.sol';
import './interfaces/IWETH.sol';
import './interfaces/IUniswapRouter.sol';
import './interfaces/IUniswapFactory.sol';
import './interfaces/IUniswapPair.sol';
import './interfaces/IGoldenTreePool.sol';
import './interfaces/ISmartArmy.sol';
import './interfaces/ISmartLadder.sol';
import './interfaces/ISmartFarm.sol';
import './interfaces/ISmartComp.sol';
import './interfaces/ISmartAchievement.sol';
import 'hardhat/console.sol';

contract SMT is Context, IBEP20, Ownable {
    using SafeMath for uint256;

    struct BuyingTokenInfo {
        uint256 price;
        uint256 decimal;
    }

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    address public _uniswapV2ETHPair;
    address public _uniswapV2BUSDPair;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    address public _operator; 
    address public _smartArmy;
    ISmartComp public comptroller;
    
    // tax addresses
    address public _referralAddress;
    address public _goldenTreePoolAddress;
    address public _devAddress;
    address public _achievementSystemAddress;
    address public _farmingRewardAddress;
    address public _intermediaryAddress;
    address public _airdropAddress;

    // Buy Tax information
    uint256 public _buyIntermediaryTaxFee = 10;
    uint256 public _buyNormalTaxFee = 15; // the % amount of buying amount when buying SMT token

    uint256 public _buyReferralFee = 50;
    uint256 public _buyGoldenPoolFee = 30;
    uint256 public _buyDevFee = 10;
    uint256 public _buyAchievementFee = 10;

    // Sell Tax information
    uint256 public _sellIntermediaryTaxFee = 10;
    uint256 public _sellNormalTaxFee = 15; // the % amount of selling amount when selling SMT token

    uint256 public _sellDevFee = 10;
    uint256 public _sellGoldenPoolFee = 30;
    uint256 public _sellFarmingFee = 20;
    uint256 public _sellBurnFee = 30;
    uint256 public _sellAchievementFee = 10;

    bool _isLockedDevTax;    
    bool _isLockedGoldenTreeTax;
    bool _isLockedFarmingTax;
    bool _isLockedBurnTax;
    bool _isLockedAchievementTax;
    bool _isLockedReferralTax;

    // Transfer Tax information
    uint256 public _transferIntermediaryTaxFee = 10;
    uint256 public _transferNormalTaxFee = 15; // the % amount of transfering amount when transfering SMT token

    uint256 public _transferDevFee = 10;
    uint256 public _transferAchievementFee = 10;
    uint256 public _transferGoldenFee = 50;
    uint256 public _transferFarmingFee = 30;

    uint256 public constant MAX_TOTAL_SUPPLY = 15000000 * 1e18;

    uint256 public _liquidityDist; // SMT-BNB liquidity distribution (locked)
    uint256 public _farmingRewardDist; // farming rewards distribution (locked)
    uint256 public _presaleDist; // presale distribution
    uint256 public _airdropDist; // airdrop distribution
    uint256 public _suprizeRewardsDist; // surprize rewards distribution (locked)
    uint256 public _chestRewardsDist; // chest rewards distribution (locked)
    uint256 public _devDist; // marketing & development distribution (unlocked)

    address[] public _whitelist;
    mapping(address => bool) mapEnabledWhitelist;

    bool _initialLiquidityLocked;
    bool _farmingRewardsLocked;
    bool _surprizeRewardsLocked;
    bool _chestRewardsLocked;
    bool _devRewardsLocked;
    bool _airdropRewardsLocked;
    
    uint256 public _tokenPriceByBusd = 15;
    uint256 public _busdDec = 10;

    uint256 public _tokenPriceByBNB = 25;
    uint256 public _bnbDec = 1000;

    bool _isSwap = false;    

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public _excludedFromFee;
    mapping(address => address) public _mapAssetToPair; // Asset --> SMT-Asset Pair
    mapping(address => BuyingTokenInfo) public _mapBuyingToken;

    event TaxAddressesUpdated(
        address indexed referral, 
        address indexed goldenTree, 
        address indexed dev, 
        address achievement, 
        address farming
    );

    event ExcludeFromFee(address indexed account, bool excluded);

    event UpdatedBuyFee(uint256 buyTaxFee);
    event UpdatedSellFee(uint256 sellTaxFee);
    event UpdatedTransferFee(uint256 transferTaxFee);

    event UpdatedBuyTaxFees(
        uint256 referralFee,
        uint256 goldenPoolFee,
        uint256 devFee,
        uint256 achievementFee        
    );
    event UpdatedSellTaxFees(
        uint256 devFee,
        uint256 goldenPoolFee,
        uint256 farmingFee,
        uint256 burnFee,
        uint256 achievementFee
    );
    event UpdatedTransferTaxFees(
        uint256 devFee,
        uint256 achievementFee,
        uint256 goldenPoolFee,
        uint256 farmingFee
    );
    event UpdatedTaxes(
        uint256 buyNormalTax,
        uint256 sellNormalTax,
        uint256 transferNormalTax,
        uint256 buyIntermediaryTax,
        uint256 sellIntermediaryTax,
        uint256 transferIntermediaryTax
    );
    event UpdatedTaxLockStatus(
        bool lockDevTax,
        bool lockGoldenTreeTax,
        bool lockFarmingTax,
        bool lockBurnTax,
        bool lockAchievementTax,
        bool lockReferralTax
    );

    event ResetedTimestamp(uint256 start_timestamp);

    event UpdatedGoldenTree(address indexed _address);
    event UpdatedSmartArmy(address indexed _address);

    event UpdatedExchangeRouter(address indexed _router);

    event AddedWhitelist(uint256 lengthOfWhitelist);
    event UpdatedWhitelistAccount(address account, bool enable);

    event CreatedPair(
        address indexed tokenA,
        address indexed tokenB
    );

    event CreatedBNBPair(address indexed _selfToken);

    event UpdatedBuyingTokenInfo(
        address _assetToken,
        uint256 _price,
        uint256 _decimal
    );

    event UpdatedBNBInfo(
        uint256 _price,
        uint256 _decimal
    );

    event TransferedOwnership(
        address oldOwner, 
        address newOwner
    );

    modifier onlyOperator() {
        require(_operator == msg.sender || msg.sender == owner(), "SMT: caller is not the operator");
        _;
    }    
    /**
     * @dev Sets the values for busdContract, {totalSupply} and tax addresses
     *
     */
    constructor(
        address smartComp,
        address dev,
        address airdrop
    ) {
        _name = "Smart Token";
        _symbol = "SMT";
        _decimals = 18;

        comptroller = ISmartComp(smartComp);
        _referralAddress = address(comptroller.getSmartLadder());
        _goldenTreePoolAddress = address(comptroller.getGoldenTreePool());
        _achievementSystemAddress = address(comptroller.getSmartAchievement());
        _farmingRewardAddress = address(comptroller.getSmartFarm());
        _intermediaryAddress = comptroller.getSmartBridge();
        _smartArmy = address(comptroller.getSmartArmy());
        _devAddress = dev;
        _airdropAddress = airdrop;
        _operator = msg.sender;

        _excludedFromFee[_referralAddress] = true;
        _excludedFromFee[_goldenTreePoolAddress] = true;
        _excludedFromFee[_achievementSystemAddress] = true;
        _excludedFromFee[_farmingRewardAddress] = true;
        _excludedFromFee[_intermediaryAddress] = true;
        _excludedFromFee[_devAddress] = true;
        _excludedFromFee[_airdropAddress] = true;
        _excludedFromFee[smartComp] = true;
        _excludedFromFee[_smartArmy] = true;

        _excludedFromFee[_operator] = true;
        _excludedFromFee[address(this)] = true;

        IUniswapV2Router02 _uniswapV2Router = comptroller.getUniswapV2Router();
        IERC20 busdContract = comptroller.getBUSD();

        _uniswapV2ETHPair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        _uniswapV2BUSDPair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), address(busdContract));

        _liquidityDist = MAX_TOTAL_SUPPLY.div(10);
        _farmingRewardDist = MAX_TOTAL_SUPPLY.div(1000).mul(383);
        _presaleDist = MAX_TOTAL_SUPPLY.div(10).mul(3);
        _airdropDist = MAX_TOTAL_SUPPLY.div(1000).mul(5);
        _suprizeRewardsDist = MAX_TOTAL_SUPPLY.div(100).mul(9);
        _chestRewardsDist = MAX_TOTAL_SUPPLY.div(1000).mul(121);
        _devDist = MAX_TOTAL_SUPPLY.div(1000);

        // mint initial liquidity to owner wallet.
        _balances[_operator] = _balances[_operator].add(_liquidityDist);
        _totalSupply = _totalSupply.add(_liquidityDist);
        emit Transfer(address(0), _operator, _liquidityDist);

        // mint some tokens to dev wallet.
        _balances[_devAddress] = _balances[_devAddress].add(_devDist);
        _totalSupply = _totalSupply.add(_devDist);
        emit Transfer(address(0), _devAddress, _devDist);

        // mint some tokens to airdrop wallet.
        _balances[_airdropAddress] = _balances[_airdropAddress].add(_airdropDist);
        _totalSupply = _totalSupply.add(_airdropDist);
        emit Transfer(address(0), _airdropAddress, _airdropDist);

        // mint tokens for farming reward to farming contract.
        _balances[_farmingRewardAddress] = _balances[_farmingRewardAddress].add(_farmingRewardDist);
        _totalSupply = _totalSupply.add(_farmingRewardDist);
        emit Transfer(address(0), _farmingRewardAddress, _farmingRewardDist);

        // mint chest rewards to achievement contract.
        _balances[_operator] = _balances[_operator].add(_chestRewardsDist);
        _totalSupply = _totalSupply.add(_chestRewardsDist);
        emit Transfer(address(0), _operator, _chestRewardsDist);
        
        // mint surprize rewards to achievement contract.
        _balances[_operator] = _balances[_operator].add(_suprizeRewardsDist);
        _totalSupply = _totalSupply.add(_suprizeRewardsDist);
        emit Transfer(address(0), _operator, _suprizeRewardsDist);
    }

    function getOwner() external override view returns (address) {
        return owner();
    }

    function getETHPair() external view returns (address) {
        return _uniswapV2ETHPair;
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

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transferFrom(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address sender, 
        address recipient, 
        uint256 amount
    ) public virtual override returns (bool) {
        _transferFrom(sender, recipient, amount);
        if(_msgSender()!=recipient || !_excludedFromFee[recipient])
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(amount, 'SMT: transfer amount exceeds allowance')
        );        
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

    function _transferFrom(
        address sender, 
        address recipient, 
        uint256 amount
    ) internal virtual {
        require(sender != address(0), 'SMT: transfer from the zero address');
        require(recipient != address(0), 'SMT: transfer to the zero address');
        require(_balances[sender] >= amount, "SMT: balance of sender is too small.");

        if (_isSwap || _excludedFromFee[sender] || _excludedFromFee[recipient]) {
            _transfer(sender, recipient, amount);
        } else {
            bool toPair = recipient == _uniswapV2ETHPair || recipient == _uniswapV2BUSDPair;
            bool fromPair = sender == _uniswapV2ETHPair || sender == _uniswapV2BUSDPair;
            if(sender == _intermediaryAddress && toPair) {
                // Intermediary => Pair: No Fee
                uint256 taxAmount = amount.mul(_sellIntermediaryTaxFee).div(100);
                uint256 recvAmount = amount.sub(taxAmount);    
                distributeSellTax(sender, taxAmount);
                _transfer(sender, recipient, recvAmount);
            } else if(fromPair && recipient == _intermediaryAddress) {
                // Pair => Intermediary: No Fee
                uint256 taxAmount = amount.mul(_buyIntermediaryTaxFee).div(100);
                uint256 recvAmount = amount.sub(taxAmount);                
                distributeBuyTax(sender, recipient, taxAmount);
                _transfer(sender, recipient, recvAmount);
            } else if(sender == _intermediaryAddress || recipient == _intermediaryAddress) {
                if (recipient == _intermediaryAddress) {
                    require(enabledIntermediary(sender), "SMT: no smart army account");
                    // sell transfer via intermediary: sell tax reduce 30%
                    uint256 taxAmount = amount.mul(_transferIntermediaryTaxFee.mul(700).div(1000)).div(100);
                    uint256 recvAmount = amount.sub(taxAmount);
                    distributeSellTax(sender, taxAmount);
                    _transfer(sender, recipient, recvAmount);
                } else {
                    require(enabledIntermediary(recipient), "SMT: no smart army account");
                    // buy transfer via intermediary: buy tax reduce 30%
                    uint256 taxAmount = amount.mul(_transferIntermediaryTaxFee.mul(700).div(1000)).div(100);
                    uint256 recvAmount = amount.sub(taxAmount);                    
                    distributeBuyTax(sender, recipient, taxAmount);
                    _transfer(sender, recipient, recvAmount);
                }
            } else if(fromPair) {
                // buy transfer
                uint256 taxAmount = amount.mul(_buyNormalTaxFee).div(100);
                uint256 recvAmount = amount.sub(taxAmount);
                distributeBuyTax(sender, recipient, taxAmount);
                _transfer(sender, recipient, recvAmount);
            } else if(toPair) {
                // sell transfer 
                uint256 taxAmount = amount.mul(_sellNormalTaxFee).div(100);
                uint256 recvAmount = amount.sub(taxAmount);
                distributeSellTax(sender, taxAmount);
                _transfer(sender, recipient, recvAmount);
            } else {
                // normal transfer
                uint256 taxAmount = amount.mul(_transferNormalTaxFee).div(100);
                uint256 recvAmount = amount.sub(taxAmount);  
                distributeTransferTax(sender, taxAmount);
                _transfer(sender, recipient, recvAmount);
            }
        }
    }

    function _transfer(address _from, address _to, uint256 _amount) internal {
        require(_balances[_from] - _amount >= 0, "amount exceeds current balance");
        _balances[_to] += _amount;
        _balances[_from] -= _amount;
        emit Transfer(_from, _to, _amount);
    }

    function _transferToGoldenTreePool(address _sender, uint256 amount) internal {
        _transfer(_sender, address(this), amount);
        _swapTokenForBUSD(_goldenTreePoolAddress, amount);
    }

    function _transferToAchievement(address _sender, uint256 amount) internal {        
        _transfer(_sender, address(this), amount);
        _swapTokenForBNB(_achievementSystemAddress, amount);
    }

    function distributeSellTax (
        address sender,
        uint256 amount
    ) internal {
        if(!_isLockedDevTax) {
            uint256 devAmount = amount.mul(_sellDevFee).div(100);
            _transfer(sender, _devAddress, devAmount);
        }
        if(!_isLockedGoldenTreeTax) {
            uint256 goldenTreeAmount = amount.mul(_sellGoldenPoolFee).div(100);
            _transfer(sender, _goldenTreePoolAddress, goldenTreeAmount);
            distributeTaxToGoldenTreePool(sender, goldenTreeAmount);
        }
        if(!_isLockedFarmingTax) {
            uint256 farmingAmount = amount.mul(_sellFarmingFee).div(100);
            _transfer(sender, _farmingRewardAddress, farmingAmount);
            distributeSellTaxToFarming(farmingAmount);
        }
        if(!_isLockedBurnTax) {
            uint256 burnAmount = amount.mul(_sellBurnFee).div(100);
            _transfer(sender, BURN_ADDRESS, burnAmount);
        }
        if(!_isLockedAchievementTax) {
            uint256 achievementAmount = amount.mul(_sellAchievementFee).div(100);
            _transfer(sender, _achievementSystemAddress, achievementAmount);
        }
    }

    /**
     * @dev Distributes buy tax tokens to tax addresses
    */
    function distributeBuyTax(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        if(!_isLockedReferralTax) {
            uint256 referralAmount = amount.mul(_buyReferralFee).div(100);
            _transfer(sender, _referralAddress, referralAmount);
            distributeBuyTaxToLadder(recipient);
        }
        if(!_isLockedGoldenTreeTax) {
            uint256 goldenTreeAmount = amount.mul(_buyGoldenPoolFee).div(100);
            _transfer(sender, _goldenTreePoolAddress, goldenTreeAmount);
            distributeTaxToGoldenTreePool(recipient, goldenTreeAmount);
        }
        if(!_isLockedDevTax) {
            uint256 devAmount = amount.mul(_buyDevFee).div(100);
            _transfer(sender, _devAddress, devAmount);
        }
        if(!_isLockedAchievementTax) {
            uint256 achievementAmount = amount.mul(_buyAchievementFee).div(100);
            _transfer(sender, _achievementSystemAddress, achievementAmount);
        }
    }

    /**
     * @dev Distributes transfer tax tokens to tax addresses
     */
    function distributeTransferTax(
        address sender,
        uint256 amount
    ) internal {

        if(!_isLockedGoldenTreeTax) {
            uint256 goldenTreeAmount = amount.mul(_transferGoldenFee).div(100);
            _transfer(sender, _goldenTreePoolAddress, goldenTreeAmount);
            distributeTaxToGoldenTreePool(sender, goldenTreeAmount);
        }
        if(!_isLockedDevTax) {
            uint256 devAmount = amount.mul(_transferDevFee).div(100);
            _transfer(sender, _devAddress, devAmount);
        }
        if(!_isLockedFarmingTax) {
            uint256 farmingAmount = amount.mul(_transferFarmingFee).div(100);
            _transfer(sender, _farmingRewardAddress, farmingAmount);
            distributeSellTaxToFarming(farmingAmount);
        }
        if(!_isLockedAchievementTax) {
            uint256 achievementAmount = amount.mul(_transferAchievementFee).div(100);
            _transfer(sender, _achievementSystemAddress, achievementAmount);
        }
    }

    /**
     * @dev Distributes buy tax tokens to smart ladder system
     */
    function distributeBuyTaxToLadder (address from) internal {
        require(_referralAddress != address(0x0), "SmartLadder can't be zero address");
        ISmartLadder(_referralAddress).distributeBuyTax(from);
    }

    /**
     * @dev Distributes sell tax tokens to farmming passive rewards pool
     */
    function distributeSellTaxToFarming (uint256 amount) internal {
        require(_farmingRewardAddress != address(0x0), "SmartFarm can't be zero address");
        ISmartFarm(_farmingRewardAddress).notifyRewardAmount(amount);
    } 

    /**
     * @dev Distribute tax to golden Tree pool as SMT and notify
     */
    function distributeTaxToGoldenTreePool (address account, uint256 amount) internal {
        require(_goldenTreePoolAddress != address(0x0), "GoldenTreePool can't be zero address");
        IGoldenTreePool(_goldenTreePoolAddress).notifyReward(amount, account);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), 'SMT: approve from the zero address');
        require(spender != address(0), 'SMT: approve to the zero address');

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Returns the address is excluded from burn fee or not.
     */
    function isExcludedFromFee(address account) external view returns (bool) {
        return _excludedFromFee[account];
    }

    /**
     * @dev Exclude the address from fee.
     */
    function excludeFromFee(address account, bool excluded) external onlyOperator {
        require(_excludedFromFee[account] != excluded, "SMT: already excluded or included");
        _excludedFromFee[account] = excluded;

        emit ExcludeFromFee(account, excluded);
    }

    function getPair(address _assetToken) public view returns(address) {
        return _mapAssetToPair[_assetToken];
    }

    function transferOwnership(address account) public override onlyOperator {
        require(account != address(0x0), "owner account can't be zero address");
        address oldOwner = _operator;
        _operator = account;
        emit TransferedOwnership(oldOwner, account);
    }

    /**
     * @dev Sets value for _sellNormalTaxFee with {sellTaxFee} in emergency status.
     */
    function setSellFee(uint256 sellTaxFee) external onlyOperator {
        require(sellTaxFee < 100, 'SMT: sellTaxFee exceeds maximum value');
        _sellNormalTaxFee = sellTaxFee;
        emit UpdatedSellFee(sellTaxFee);
    }

    /**
     * @dev Sets value for _buyNormalTaxFee with {buyTaxFee} in emergency status.
     */
    function setBuyFee(uint256 buyTaxFee) external onlyOperator {
        require(buyTaxFee < 100, 'SMT: buyTaxFee exceeds maximum value');
        _buyNormalTaxFee = buyTaxFee;
        emit UpdatedBuyFee(buyTaxFee);
    }    

    /**
     * @dev Sets value for _transferNormalTaxFee with {transferTaxFee} in emergency status.
     */
    function setTransferFee (uint256 transferTaxFee) external onlyOperator {
        require(transferTaxFee < 100, 'SMT: transferTaxFee exceeds maximum value');
        _transferNormalTaxFee = transferTaxFee;
        emit UpdatedTransferFee(transferTaxFee);
    }  

    /**
     *  @dev reset new router. 
    */
    function setSmartComp(
        address _smartComp
    ) public onlyOperator {
        require(address(_smartComp) != address(0x0), "Smart Comp address can't be zero address");
        comptroller = ISmartComp(_smartComp);
    }

    /**
     *  @dev reset new liquidity pool based on router. 
    */
    function createBNBPair() public onlyOperator {
        require(address(comptroller) != address(0x0), "SmartComp address can't be zero address");        
        IUniswapV2Router02 router = comptroller.getUniswapV2Router();
        _uniswapV2ETHPair = IUniswapV2Factory(router.factory())
            .createPair(address(this), router.WETH());
        emit CreatedBNBPair(address(this));
    }    

    function createBUSDPair(address _busdToken) public onlyOperator {
        createPair(_busdToken);
        _uniswapV2BUSDPair = getPair(_busdToken);
    }

    /**
     *  @dev reset new liquidity pool based on router. 
    */
    function createPair(address _assetToken) public onlyOperator {
        require(address(comptroller) != address(0x0), "SmartComp can't be zero address");
        require(address(_assetToken) != address(0x0), "Asset token address can't be zero address");

        IUniswapV2Router02 router = comptroller.getUniswapV2Router();
        address pairAsset = IUniswapV2Factory(router.factory()).createPair(address(this), _assetToken);
        _mapAssetToPair[_assetToken] = pairAsset;
        emit CreatedPair(address(this), _assetToken);
    }

    /**
     *  @dev Sets tax fees
    */
    function setTaxLockStatus(
        bool lockDevTax,
        bool lockGoldenTreeTax,
        bool lockFarmingTax,
        bool lockBurnTax,
        bool lockAchievementTax,
        bool lockReferralTax
    ) external onlyOperator {
        _isLockedDevTax = lockDevTax;
        _isLockedGoldenTreeTax = lockGoldenTreeTax;
        _isLockedFarmingTax = lockFarmingTax;
        _isLockedBurnTax = lockBurnTax;
        _isLockedAchievementTax = lockAchievementTax;
        _isLockedReferralTax = lockReferralTax;
        emit UpdatedTaxLockStatus(
            lockDevTax,
            lockGoldenTreeTax,
            lockFarmingTax,
            lockBurnTax,
            lockAchievementTax,
            lockReferralTax
        );
    }

    /**
     *  @dev Sets tax fees
    */
    function setTaxFees(
        uint256 buyNormalTax,
        uint256 sellNormalTax,
        uint256 transferNormalTax,
        uint256 buyIntermediaryTax,
        uint256 sellIntermediaryTax,
        uint256 transferIntermediaryTax
    ) external onlyOperator {
        _buyNormalTaxFee = buyNormalTax;
        _sellNormalTaxFee = sellNormalTax;
        _transferNormalTaxFee = transferNormalTax;
        _buyIntermediaryTaxFee = buyIntermediaryTax;
        _sellIntermediaryTaxFee = sellIntermediaryTax;
        _transferIntermediaryTaxFee = transferIntermediaryTax;
        emit UpdatedTaxes(
            buyNormalTax,
            sellNormalTax,
            transferNormalTax,
            buyIntermediaryTax,
            sellIntermediaryTax,
            transferIntermediaryTax
        );
    }

    /**
     *  @dev Sets buying tax fees
    */
    function setBuyTaxFees(
        uint256 referralFee,
        uint256 goldenPoolFee,
        uint256 devFee,
        uint256 achievementFee
    ) external onlyOperator {
        _buyReferralFee = referralFee;
        _buyGoldenPoolFee = goldenPoolFee;
        _buyDevFee = devFee;
        _buyAchievementFee = achievementFee;
        emit UpdatedBuyTaxFees(
            referralFee, 
            goldenPoolFee, 
            devFee, 
            achievementFee
        );
    }

    /**
     *  @dev Sets selling tax fees
    */
    function setSellTaxFees(
        uint256 devFee,
        uint256 goldenPoolFee,
        uint256 farmingFee,
        uint256 burnFee,
        uint256 achievementFee
    ) external onlyOperator {
        _sellDevFee = devFee;
        _sellGoldenPoolFee = goldenPoolFee;
        _sellFarmingFee = farmingFee;
        _sellBurnFee = burnFee;
        _sellAchievementFee = achievementFee;
        emit UpdatedSellTaxFees(
            devFee, 
            goldenPoolFee, 
            farmingFee, 
            burnFee, 
            achievementFee
        );
    }

    /**
     *  @dev Sets buying tax fees
    */
    function setTransferTaxFees(
        uint256 devFee,
        uint256 achievementFee,
        uint256 goldenPoolFee,
        uint256 farmingFee
    ) external onlyOperator {
        _transferDevFee = devFee;
        _transferAchievementFee = achievementFee;
        _transferGoldenFee = goldenPoolFee;
        _transferFarmingFee = farmingFee;
        emit UpdatedTransferTaxFees(
            devFee, 
            achievementFee, 
            goldenPoolFee, 
            farmingFee
        );
    }

    /**
     *  @dev Sets values for tax addresses 
     */
    function setTaxAddresses(
        address referral, 
        address goldenTree, 
        address achievement, 
        address farming, 
        address intermediary,
        address dev, 
        address airdrop
    ) external onlyOperator {

        if (_referralAddress != referral && referral != address(0x0)) {
            _excludedFromFee[_referralAddress] = false;
            _referralAddress = referral;
            _excludedFromFee[referral] = true;
        }
        if (_goldenTreePoolAddress != goldenTree && goldenTree != address(0x0)) {
            _excludedFromFee[_goldenTreePoolAddress] = false;
            _goldenTreePoolAddress = goldenTree;
            _excludedFromFee[goldenTree] = true;
        }
        if (_devAddress != dev && dev != address(0x0)) {
            _excludedFromFee[_devAddress] = false;
            _devAddress = dev;
            _excludedFromFee[dev] = true;
        }
        if (_achievementSystemAddress != achievement && achievement != address(0x0)) {
            _excludedFromFee[_achievementSystemAddress] = false;
            _achievementSystemAddress = achievement;
            _excludedFromFee[achievement] = true;
        }
        if (_farmingRewardAddress != farming && farming != address(0x0)) {
            _excludedFromFee[_farmingRewardAddress] = false;
            _farmingRewardAddress = farming;
            _excludedFromFee[farming] = true;
        }
        if (_airdropAddress != airdrop && airdrop != address(0x0)) {
            _excludedFromFee[_airdropAddress] = false;
            _airdropAddress = airdrop;
            _excludedFromFee[airdrop] = true;
        }
        if (_intermediaryAddress != intermediary && intermediary != address(0x0)) {
            _intermediaryAddress = intermediary;
        }
        emit TaxAddressesUpdated(referral, goldenTree, dev, achievement, farming);
    }

    /**
     * @dev Sets value for _goldenTreePoolAddress
     */
    function setGoldenTreeAddress (address _address) external onlyOperator {
        require(_address!= address(0x0), 'SMT: not allowed zero address');
        _goldenTreePoolAddress = _address;

        emit UpdatedGoldenTree(_address);
    }

    /**
     * @dev Sets value for _smartArmy
     */
    function setSmartArmyAddress(address _address) external onlyOperator {
        require(_address!= address(0x0), 'SMT: not allowed zero address');
        _smartArmy = _address;

        emit UpdatedSmartArmy(_address);
    }
    
    function enabledIntermediary(address account) public view returns (bool){
        if(_smartArmy == address(0x0)) {
            return false;
        }
        return ISmartArmy(_smartArmy).isEnabledIntermediary(account);
    }

    function _swapTokenForBUSD(address to, uint256 tokenAmount) private {
        _isSwap = true;
        IERC20 busdToken = comptroller.getBUSD();
        IUniswapV2Router02 uniswapV2Router = comptroller.getUniswapV2Router();

        // generate the uniswap pair path of token -> busd
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = address(busdToken);

        _approve(address(this), address(uniswapV2Router), tokenAmount);
        // make the swap
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            to,
            block.timestamp
        );
        _isSwap = false;
    }

    function _swapTokenForBNB(address to, uint256 tokenAmount) private {
        _isSwap = true;
        IUniswapV2Router02 uniswapV2Router = comptroller.getUniswapV2Router();

        // generate the uniswap pair path of token -> busd
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = address(uniswapV2Router.WETH());

        _approve(address(this), address(uniswapV2Router), tokenAmount);
        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            to,
            block.timestamp
        );
        _isSwap = false;
    }
}

