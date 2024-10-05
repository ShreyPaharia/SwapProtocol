// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap-periphery/interfaces/ISwapRouter.sol";
import "@permit2/contracts/interfaces/IPermit2.sol";

contract SwapProtocol is Ownable {
    ISwapRouter public immutable uniswapRouter;
    IPermit2 public immutable permit2;

    uint256 public feePercent; // Fee is in percentage (20% by default)

    struct SwapIntent {
        address tokenIn;
        uint256 amountIn;
        address tokenOut;
        uint256 minAmountOut;
        bytes permit2Sig;
    }

    event SwapExecuted(
        address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, uint256 fee
    );

    event FeeUpdated(uint256 newFeePercent);
    event FeesWithdrawn(address token, uint256 amount);

    mapping(address => uint256) public feesCollected;

    constructor(address _uniswapRouter, address _permit2, uint256 _feePercent) {
        require(_feePercent <= 100, "Fee too high");
        uniswapRouter = ISwapRouter(_uniswapRouter);
        permit2 = IPermit2(_permit2);
        feePercent = _feePercent;
    }

    function swap(SwapIntent calldata intent) external payable {
        if (intent.tokenIn == address(0)) {
            // Handle ETH case
            require(msg.value == intent.amountIn, "Incorrect ETH sent");
        } else {
            // Handle ERC20 case via permit2
            permit2.permit(msg.sender, address(this), intent.permit2Sig);

            IERC20(intent.tokenIn).transferFrom(msg.sender, address(this), intent.amountIn);
        }

        uint256 amountOut = _swapTokens(intent.tokenIn, intent.amountIn, intent.tokenOut, msg.sender);

        require(amountOut >= intent.minAmountOut, "Insufficient output");

        uint256 fee = 0;
        if (amountOut > intent.minAmountOut) {
            fee = ((amountOut - intent.minAmountOut) * feePercent) / 100;
            feesCollected[intent.tokenOut] += fee;
            amountOut -= fee;
        }

        if (intent.tokenOut == address(0)) {
            payable(msg.sender).transfer(amountOut);
        } else {
            IERC20(intent.tokenOut).transfer(msg.sender, amountOut);
        }

        emit SwapExecuted(msg.sender, intent.tokenIn, intent.tokenOut, intent.amountIn, amountOut, fee);
    }

    function setFeePercent(uint256 _feePercent) external onlyOwner {
        require(_feePercent <= 100, "Fee too high");
        feePercent = _feePercent;
        emit FeeUpdated(_feePercent);
    }

    function withdrawFees(address token) external onlyOwner {
        uint256 amount = feesCollected[token];
        require(amount > 0, "No fees to withdraw");

        feesCollected[token] = 0;

        if (token == address(0)) {
            payable(owner()).transfer(amount);
        } else {
            IERC20(token).transfer(owner(), amount);
        }

        emit FeesWithdrawn(token, amount);
    }

    function _swapTokens(address tokenIn, uint256 amountIn, address tokenOut, address to)
        internal
        returns (uint256 amountOut)
    {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: 3000, // Example pool fee
            recipient: to,
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        amountOut = uniswapRouter.exactInputSingle{value: tokenIn == address(0) ? amountIn : 0}(params);
    }

    receive() external payable {}
}
