// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {SwapProtocol} from "../src/SwapProtocol.sol";
import {ISignatureTransfer} from "@permit2/interfaces/ISignatureTransfer.sol";
import {ISwapRouter} from "@uniswap-periphery/interfaces/ISwapRouter.sol";
import {IQuoterV2} from "@uniswap-periphery/interfaces/IQuoterV2.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

contract SwapProtocolTest is Test {
    ISwapRouter public constant UNISWAP_ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IQuoterV2 public constant QUOTER = IQuoterV2(0x61fFE014bA17989E743c5F6cB21bF9697530B21e);
    ISignatureTransfer public constant PERMIT2 = ISignatureTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 public constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    SwapProtocol public swapProtocol;
    address public owner;
    address public user;
    uint256 public userPrivateKey;
    bytes32 public DOMAIN_SEPARATOR;

    bytes32 public constant _TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 public constant _PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    function setUp() public {
        // Fork the Ethereum mainnet
        vm.createSelectFork("https://eth-mainnet.g.alchemy.com/v2/-vgQHEEyUqPHMIT3pnMzzE_8xNelx7sj");
        vm.rollFork(20900000);

        // Deploy the SwapProtocol contract
        owner = address(this);
        swapProtocol = new SwapProtocol(address(UNISWAP_ROUTER), address(PERMIT2), 20); // 20% fee initially
        DOMAIN_SEPARATOR = PERMIT2.DOMAIN_SEPARATOR();

        // Create a user account for testing
        userPrivateKey = 0x59c6995e998f97a5a0044974f9e79dfb2b63c22e5a7bdef7c12e7c287b52db1b; // Replace with your test private key
        user = vm.addr(userPrivateKey);

        swapProtocol.approveRouter(USDC);
        swapProtocol.approveRouter(WETH);

        // Give user some USDC and ETH for testing
        deal(address(USDC), user, 1_000_000 * 1e6); // 1 million USDC
        deal(user, 100 * 1e18); // 100 ETH
    }

    function testSwapWithERC20() public {
        vm.startPrank(user);

        uint256 startWETHBalance = WETH.balanceOf(user);
        uint256 startSwapProtocolBalance = WETH.balanceOf(address(swapProtocol));
        uint256 startUSDCBalance = USDC.balanceOf(user);

        USDC.approve(address(PERMIT2), type(uint256).max);

        uint256 amountIn = 1000 * 1e6; // 1000 USDC
        uint256 minAmountOut = 0.1 * 1e18; // Minimum 0.1 WETH expected out

        // Create Permit2 signature
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(USDC), amount: amountIn}),
            nonce: 0,
            deadline: block.timestamp + 1 hours
        });

        bytes memory signature = createPermitSignature(userPrivateKey, address(swapProtocol), permit);

        // Prepare SwapIntent
        SwapProtocol.SwapIntent memory intent = SwapProtocol.SwapIntent({
            tokenIn: address(USDC),
            amountIn: amountIn,
            tokenOut: address(WETH),
            minAmountOut: minAmountOut,
            permit: permit,
            permitSig: signature
        });

        IQuoterV2.QuoteExactInputSingleParams memory quoteParams = IQuoterV2.QuoteExactInputSingleParams({
            tokenIn: address(USDC),
            tokenOut: address(WETH),
            amountIn: amountIn,
            fee: 3000, // Uniswap fee tier (0.3%)
            sqrtPriceLimitX96: 0
        });
        // Use QuoterV2 to get the expected amountOut
        (uint256 expectedAmountOut,,,) = QUOTER.quoteExactInputSingle(quoteParams);

        // Execute swap
        swapProtocol.swap(intent);

        // Verify balance changes
        uint256 endWETHBalance = WETH.balanceOf(user);
        uint256 endSwapProtocolBalance = WETH.balanceOf(address(swapProtocol));
        uint256 endUSDCBalance = USDC.balanceOf(user);

        uint256 expectedFee = ((expectedAmountOut - minAmountOut) * 20) / 100;

        assertEq(endUSDCBalance, startUSDCBalance - amountIn, "Incorrect USDC balance");
        assertEq(endWETHBalance, startWETHBalance + expectedAmountOut - expectedFee, "Incorrect WETH balance");
        assertEq(endSwapProtocolBalance, startSwapProtocolBalance + expectedFee, "Incorrect SwapProtocol balance");

        vm.stopPrank();
    }

    function testSwapWithETH() public {
        vm.startPrank(user);

        uint256 startUSDCBalance = USDC.balanceOf(user);
        uint256 startETHBalance = user.balance;
        uint256 startSwapProtocolBalance = USDC.balanceOf(address(swapProtocol));

        uint256 amountIn = 1 * 1e18; // 1 ETH
        uint256 minAmountOut = 1000 * 1e6; // Minimum 1000 USDC expected out

        // Create Permit2 signature
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(0), amount: amountIn}),
            nonce: 0,
            deadline: 0
        });

        // Prepare SwapIntent
        SwapProtocol.SwapIntent memory intent = SwapProtocol.SwapIntent({
            tokenIn: address(0),
            amountIn: amountIn,
            tokenOut: address(USDC),
            minAmountOut: minAmountOut,
            permit: permit,
            permitSig: ""
        });

        IQuoterV2.QuoteExactInputSingleParams memory quoteParams = IQuoterV2.QuoteExactInputSingleParams({
            tokenIn: address(WETH),
            tokenOut: address(USDC),
            amountIn: amountIn,
            fee: 3000, // Uniswap fee tier (0.3%)
            sqrtPriceLimitX96: 0
        });
        // Use QuoterV2 to get the expected amountOut
        (uint256 expectedAmountOut,,,) = QUOTER.quoteExactInputSingle(quoteParams);

        // Execute swap
        swapProtocol.swap{value: amountIn}(intent);

        // Verify the swap results
        uint256 endUSDCBalance = USDC.balanceOf(user);
        uint256 endETHBalance = user.balance;
        uint256 endSwapProtocolBalance = USDC.balanceOf(address(swapProtocol));

        uint256 expectedFee = ((expectedAmountOut - minAmountOut) * 20) / 100;

        assertEq(endETHBalance, startETHBalance - amountIn, "Incorrect ETH balance");
        assertEq(endUSDCBalance, startUSDCBalance + expectedAmountOut - expectedFee, "Incorrect USDC balance");
        assertEq(endSwapProtocolBalance, startSwapProtocolBalance + expectedFee, "Incorrect SwapProtocol balance");

        vm.stopPrank();
    }

    // Helper function to create Permit2 signature
    function createPermitSignature(
        uint256 privateKey,
        address spender,
        ISignatureTransfer.PermitTransferFrom memory permit
    ) internal view returns (bytes memory) {
        bytes32 tokenPermissions = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(_PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissions, spender, permit.nonce, permit.deadline)
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }
}
