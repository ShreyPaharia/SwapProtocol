# Fastlane-Test

## Project Overview

This project implements a minimal swapping protocol that allows users to swap tokens using Uniswap, leveraging Permit2 for token approvals. The protocol is designed to be secure, gas-optimized, and readable. It includes functionality for the protocol owner to adjust fees and withdraw earned fees.

## Problem Statement

Build a minimal swapping protocol that lets a user pass in a `SwapIntent` struct which includes `tokenIn`, `amountIn`, `tokenOut`, `minAmountOut`, and a `permit2` signature. The protocol then pulls the tokens from the user without the user having approved it before, using the `permit2` signature. The protocol then performs the swap via Uniswap and sends back the expected amount of `tokenOut` to the user. If the swap results in more than the user's `minAmountOut`, the protocol keeps 20% of the excess amount above the `minAmountOut` as a fee. The protocol owner should be able to adjust the 20% fee after the protocol is deployed, to any value between 0% and 100%, and should be able to withdraw the fees earned. All code should be secure against exploits, gas-optimized, and readable (in that order of importance). Make 2 Foundry tests showing that it works: the first test where `tokenIn` is an ERC20 and the second test where `tokenIn` is ETH.

## Solution

### SwapProtocol.sol

The `SwapProtocol` contract is implemented in Solidity and includes the following key features:

- **SwapIntent Struct**: Defines the structure for swap intents, including `tokenIn`, `amountIn`, `tokenOut`, `minAmountOut`, `permit`, and `permitSig`.
- **Permit2 Integration**: Uses Permit2 to pull tokens from the user without prior approval.
- **Uniswap Integration**: Executes swaps via Uniswap's `ISwapRouter`.
- **Fee Mechanism**: Keeps 20% of the excess amount above `minAmountOut` as a fee, which can be adjusted by the owner.
- **Owner Functions**: Allows the owner to update the fee percentage and withdraw collected fees.

### SwapProtocolTest.sol

The `SwapProtocolTest` contract includes Foundry tests to verify the functionality of the `SwapProtocol` contract:

- **testSwapWithERC20**: Tests the swap functionality where `tokenIn` is an ERC20 token.
- **testSwapWithETH**: Tests the swap functionality where `tokenIn` is ETH.

### Usage

1. **Deploy the Contract**: Deploy the `SwapProtocol` contract with the Uniswap router address, Permit2 address, and initial fee percentage.
2. **Approve Router**: The owner should approve the Uniswap router to spend the tokens.
3. **Create SwapIntent**: Users create a `SwapIntent` struct and sign it using Permit2.
4. **Execute Swap**: Users call the `swap` function with the `SwapIntent` struct to perform the swap.
5. **Adjust Fees**: The owner can adjust the fee percentage using the `updateFeePercent` function.
6. **Withdraw Fees**: The owner can withdraw collected fees using the `withdrawFees` function.

### Security Considerations

- **Reentrancy Guard**: The contract uses OpenZeppelin's `ReentrancyGuard` to prevent reentrancy attacks.
- **Custom Errors**: Custom errors are used for better gas efficiency and readability.
- **Permit2**: Ensures that tokens are pulled securely from the user without prior approval.

### Gas Optimization

- **Immutable Variables**: The Uniswap router and Permit2 addresses are marked as immutable to save gas.
- **Efficient Calculations**: Fee calculations and token transfers are optimized for gas efficiency.

### Readability

- **Structured Code**: The code is structured and commented for better readability.
- **Custom Errors**: Custom errors provide clear and concise error messages.

## Conclusion

This project provides a secure, gas-optimized, and readable solution for a minimal swapping protocol using Uniswap and Permit2. The protocol includes functionality for fee adjustments and fee withdrawals, ensuring flexibility and usability for the protocol owner.
