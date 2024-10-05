// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {ISignatureTransfer} from "@permit2/interfaces/ISignatureTransfer.sol";
import {ISwapRouter} from "@uniswap-periphery/interfaces/ISwapRouter.sol";

contract SwapProtocol is ReentrancyGuard {
    ISwapRouter public immutable uniswapRouter;
    ISignatureTransfer public immutable permit2;
    address public owner;
    uint256 public feePercent; // feePercent is a value between 0 to 100
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

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
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _uniswapRouter, address _permit2, uint256 _initialFeePercent) {
        require(_initialFeePercent <= 100, "Invalid fee percent");
        uniswapRouter = ISwapRouter(_uniswapRouter);
        permit2 = ISignatureTransfer(_permit2);
        owner = msg.sender;
        feePercent = _initialFeePercent;
    }

    // Owner can update the fee percentage
    function updateFeePercent(uint256 newFeePercent) external onlyOwner {
        require(newFeePercent <= 100, "Invalid fee percent");
        feePercent = newFeePercent;
    }

    // Withdraw collected fees by owner
    function withdrawFees(IERC20 token) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No fees to withdraw");
        token.transfer(owner, balance);
    }

    // Main function to handle the swap
    function swap(SwapIntent calldata intent) external payable nonReentrant {
        uint256 amountIn = intent.amountIn;
        address tokenIn;

        if (intent.tokenIn == address(0)) {
            // Handle ETH
            require(msg.value == amountIn, "Incorrect ETH amount");
            // Wrap ETH to WETH
            (bool success,) = WETH.call{value: msg.value}("");
            require(success, "Failed to wrap ETH");
            tokenIn = WETH;
        } else {
            // Transfer tokens from user using Permit2
            ISignatureTransfer.SignatureTransferDetails memory transferDetails =
                ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: amountIn});

            permit2.permitTransferFrom(intent.permit, transferDetails, msg.sender, intent.permitSig);
            // Swap logic via Uniswap V3
            tokenIn = intent.tokenIn;
        }
        IERC20(tokenIn).approve(address(uniswapRouter), amountIn);
        uint256 amountOut = _swapTokenToToken(tokenIn, intent.tokenOut, amountIn, intent.minAmountOut);

        // Calculate fee and transfer the remaining tokens to the user
        if (amountOut > intent.minAmountOut) {
            uint256 excessAmount = amountOut - intent.minAmountOut;
            uint256 fee = (excessAmount * feePercent) / 100;

            IERC20 tokenOut = IERC20(intent.tokenOut);
            tokenOut.transfer(msg.sender, amountOut - fee);
            tokenOut.transfer(owner, fee); // Send fee to the protocol owner
        } else {
            IERC20(intent.tokenOut).transfer(msg.sender, amountOut);
        }
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
