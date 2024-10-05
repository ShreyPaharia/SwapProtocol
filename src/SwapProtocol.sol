// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {ISignatureTransfer} from "@permit2/interfaces/ISignatureTransfer.sol";
import {ISwapRouter} from "@uniswap-periphery/interfaces/ISwapRouter.sol";

contract SwapProtocol is ReentrancyGuard {
    ISwapRouter public immutable uniswapRouter;
    ISignatureTransfer public immutable permit2;
    address public immutable owner;
    uint256 public feePercent; // feePercent is a value between 0 to 100
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Custom Errors
    error NotOwner();
    error InvalidFeePercent(uint256 feePercent);
    error NoFeesToWithdraw();
    error IncorrectETHAmount(uint256 provided, uint256 expected);
    error TransferFailed();
    error InsufficientOutputAmount(uint256 actual, uint256 minimum);

    // Swap intent struct
    struct SwapIntent {
        address tokenIn;
        uint256 amountIn;
        address tokenOut;
        uint256 minAmountOut;
        ISignatureTransfer.PermitTransferFrom permit;
        bytes permitSig;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _uniswapRouter, address _permit2, uint256 _initialFeePercent) {
        if (_initialFeePercent > 100) revert InvalidFeePercent(_initialFeePercent);
        uniswapRouter = ISwapRouter(_uniswapRouter);
        permit2 = ISignatureTransfer(_permit2);
        owner = msg.sender;
        feePercent = _initialFeePercent;
    }

    // Owner can update the fee percentage
    function updateFeePercent(uint256 newFeePercent) external onlyOwner {
        if (newFeePercent > 100) revert InvalidFeePercent(newFeePercent);
        feePercent = newFeePercent;
    }

    // Withdraw collected fees by owner
    function withdrawFees(IERC20 token) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) revert NoFeesToWithdraw();
        token.transfer(owner, balance);
    }

    function approveRouter(IERC20 token) external onlyOwner {
        token.approve(address(uniswapRouter), type(uint256).max);
    }

    // Main function to handle the swap
    function swap(SwapIntent calldata intent) external payable nonReentrant {
        uint256 amountIn = intent.amountIn;
        address tokenIn; // Check for ETH and set tokenIn accordingly

        if (intent.tokenIn == address(0)) {
            if (msg.value != amountIn) revert IncorrectETHAmount(msg.value, amountIn);
            (bool success,) = WETH.call{value: msg.value}("");
            if (!success) revert TransferFailed();
            tokenIn = WETH;
        } else {
            permit2.permitTransferFrom(
                intent.permit,
                ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: amountIn}),
                msg.sender,
                intent.permitSig
            );
            tokenIn = intent.tokenIn;
        }

        uint256 amountOut = _swapTokenToToken(tokenIn, intent.tokenOut, amountIn, intent.minAmountOut);

        uint256 fee = (amountOut > intent.minAmountOut) ? (amountOut - intent.minAmountOut) * feePercent / 100 : 0;

        IERC20(intent.tokenOut).transfer(msg.sender, amountOut - fee); // Send the remaining tokens to the user
    }

    // Internal swap function from one ERC20 token to another
    function _swapTokenToToken(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut)
        internal
        returns (uint256)
    {
        // Create the swap parameters (adjust for your use case)
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: 3000, // 0.3% Uniswap fee tier
            recipient: address(this),
            deadline: block.timestamp + 120,
            amountIn: amountIn,
            amountOutMinimum: minAmountOut,
            sqrtPriceLimitX96: 0
        });

        // Execute the swap on Uniswap
        return uniswapRouter.exactInputSingle(params);
    }
}
