// SPDX-License-Identifier: MIT

/**
 * SMTC Pancake bridge - SMT Intermediary
 * @author Liu
 */

pragma solidity 0.8.4;

import "./libs/UniswapV2Library.sol";
import "./interfaces/IUniswapFactory.sol";
import "./interfaces/IUniswapRouter.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/ISmartComp.sol";
import './libs/TransferHelper.sol';

import '@openzeppelin/contracts/access/Ownable.sol';
import "hardhat/console.sol";

contract SMTBridge is Ownable {
    using SafeMath for uint256;

    address public WBNB;
    address public pancakeFactory;
    
    uint256 public aggregatorFee = 0; // Default to 0.0%
    uint256 public constant FEE_DENOMINATOR = 10 ** 10;

    ISmartComp public comptroller;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'SMTBridge: EXPIRED');
        _;
    }

    constructor (
        address _wbnb,
        address _factory,
        ISmartComp _comptroller
    ) {
        require(_wbnb != address(0), "SMTBridge: ZERO_WBNB_ADDRESS");
        require(_factory != address(0), "SMTBridge: ZERO_FACTORY_ADDRESS");
        require(address(_comptroller) != address(0), "SMTBridge: ZERO_SMARTCOMP_ADDRESS");
        
        WBNB = _wbnb;
        pancakeFactory = _factory;
        comptroller = _comptroller;
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint swapAmountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) {
        uint amountOut = _swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, swapAmountOutMin, path);
        uint feeAmount = amountOut.mul(aggregatorFee).div(FEE_DENOMINATOR);

        uint adjustedAmountOut = amountOut.sub(feeAmount);
        TransferHelper.safeTransfer(path[path.length - 1], to, adjustedAmountOut);
    }

    function _swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path
    ) internal virtual returns (uint) {
        _transferTokenToPair(
            path[0], msg.sender, UniswapV2Library.pairFor(pancakeFactory, path[0], path[1]), amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(address(this));
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(path[path.length - 1]).balanceOf(address(this)).sub(balanceBefore);
        require(amountOut >= amountOutMin, 'SMTBridge: INSUFFICIENT_OUTPUT_AMOUNT');
        return amountOut;
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint swapAmountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual payable ensure(deadline) {
        uint amountOut = _swapExactETHForTokensSupportingFeeOnTransferTokens(swapAmountOutMin, path, 0);
        uint feeAmount = amountOut.mul(aggregatorFee).div(FEE_DENOMINATOR);

        uint adjustedAmountOut = amountOut.sub(feeAmount);
        TransferHelper.safeTransfer(path[path.length - 1], to, adjustedAmountOut);
    }

    function _swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint swapAmountOutMin,
        address[] calldata path,
        uint fee
    ) internal virtual returns (uint) {
        require(path[0] == WBNB, 'SMTBridge: INVALID_PATH');
        uint amountIn = msg.value.sub(fee);
        require(amountIn > 0, 'SMTBridge: INSUFFICIENT_INPUT_AMOUNT');
        IWETH(WBNB).deposit{value: amountIn}();
        assert(IWETH(WBNB).transfer(UniswapV2Library.pairFor(pancakeFactory, path[0], path[1]), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(address(this));
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(path[path.length - 1]).balanceOf(address(this)).sub(balanceBefore);
        require(amountOut >= swapAmountOutMin, 'SMTBridge: INSUFFICIENT_OUTPUT_AMOUNT');
        return amountOut;
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint swapAmountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) {
        uint amountOut = _swapExactTokensForETHSupportingFeeOnTransferTokens(amountIn, swapAmountOutMin, path);
        uint feeAmount = amountOut.mul(aggregatorFee).div(FEE_DENOMINATOR);

        IWETH(WBNB).withdraw(amountOut);
        uint adjustedAmountOut = amountOut.sub(feeAmount);
        TransferHelper.safeTransferETH(to, adjustedAmountOut);
    }

    function _swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint swapAmountOutMin,
        address[] calldata path
    ) internal virtual returns (uint) {
        require(path[path.length - 1] == WBNB, 'SMTBridge: INVALID_PATH');
        _transferTokenToPair(
            path[0], msg.sender, UniswapV2Library.pairFor(pancakeFactory, path[0], path[1]), amountIn
        );
        uint balanceBefore = IERC20(WBNB).balanceOf(address(this));
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WBNB).balanceOf(address(this)).sub(balanceBefore);
        require(amountOut >= swapAmountOutMin, 'SMTBridge: INSUFFICIENT_OUTPUT_AMOUNT');
        return amountOut;
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            require(IUniswapV2Factory(pancakeFactory).getPair(input, output) != address(0), "SMTBridge: PAIR_NOT_EXIST");
            IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(pancakeFactory, input, output));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = UniswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(pancakeFactory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
////////////////////////////////////////////////////////////////////////
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
        path[1] = address(smtToken);
        path[0] = address(busdToken);

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
///////////////////////////////////////////////////////////////////////
    // Transfer token from User => This => Pair
    function _transferTokenToPair(address token, address from, address pair, uint value) internal {
        // First transfer token to this
        uint balanceBefore = IERC20(token).balanceOf(address(this));
        TransferHelper.safeTransferFrom(
            token, from, address(this), value
        );
        uint amountIn = IERC20(token).balanceOf(address(this)).sub(balanceBefore);
        
        // Second Transfer token to pair from this
        TransferHelper.safeTransfer(token, pair, amountIn);
    }

    receive() external payable { }

    function collect(address token) external {
        if (token == WBNB) {
            uint256 wethBalance = IERC20(token).balanceOf(address(this));
            if (wethBalance > 0) {
                IWETH(WBNB).withdraw(wethBalance);
            }
            TransferHelper.safeTransferETH(owner(), address(this).balance);
        } else {
            TransferHelper.safeTransfer(token, owner(), IERC20(token).balanceOf(address(this)));
        }
    }

    function setAggregatorFee(uint _fee) external onlyOwner {
        aggregatorFee = _fee;
    }

    function setPancakeFactory(address _factory) external onlyOwner {
        pancakeFactory = _factory;
    }

    function setWBNB(address _wbnb) external onlyOwner {
        WBNB = _wbnb;
    }
}