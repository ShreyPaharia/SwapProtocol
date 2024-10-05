// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SwapProtocol.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SwapProtocolTest is Test {
    SwapProtocol swapProtocol;
    ISwapRouter uniswapRouter;
    IPermit2 permit2;
    IERC20 tokenA;
    IERC20 tokenB;

    function setUp() public {
        uniswapRouter = ISwapRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); // Uniswap router address
        permit2 = IPermit2(0x31c2f6fcff4f8759b3bd5bf0e1084a055615c768); // Permit2 address
        tokenA = IERC20(0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48); // ERC20 Token A
        tokenB = IERC20(0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2); // ERC20 Token B

        swapProtocol = new SwapProtocol(address(uniswapRouter), address(permit2), 20);
    }

    function testSwapWithERC20() public {
        uint256 amountIn = 100 * 10**18;
        uint256 minAmountOut = 90 * 10**18;

        bytes memory permitSig = ... ; // Use Permit2 to get a valid signature

        SwapProtocol.SwapIntent memory intent = SwapProtocol.SwapIntent({
            tokenIn: address(tokenA),
            amountIn: amountIn,
            tokenOut: address(tokenB),
            minAmountOut: minAmountOut,
            permit2Sig: permitSig
        });

        tokenA.approve(address(swapProtocol), amountIn);

        swapProtocol.swap(intent);
        // Assertions for amountOut, fees, etc.
    }

    function testSwapWithETH() public {
        uint256 amountIn = 1 ether;
        uint256 minAmountOut = 0.9 ether;

        SwapProtocol.SwapIntent memory intent = SwapProtocol.SwapIntent({
            tokenIn: address(0),
            amountIn: amountIn,
            tokenOut: address(tokenB),
            minAmountOut: minAmountOut,
            permit2Sig: ""
        });

        swapProtocol.swap{value: amountIn}(intent);
        // Assertions for amountOut, fees, etc.
    }
}
