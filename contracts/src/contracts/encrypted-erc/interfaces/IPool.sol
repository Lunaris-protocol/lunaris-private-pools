// (c) 2025, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

// SPDX-License-Identifier: Ecosystem
pragma solidity 0.8.28;

import {EGCT, TransferProof} from "../types/Types.sol";

/**
 * @title IPool
 * @notice Interface for the Pool contract
 */
interface IPool {
    /**
     * @notice Emitted when a swap occurs
     */
    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256[7] auditorPCT
    );

    /**
     * @notice Emitted when liquidity is added
     */
    event LiquidityAdded(
        address indexed provider,
        EGCT liquidityAmount,
        uint256[7] auditorPCT
    );

    /**
     * @notice Emitted when liquidity is removed
     */
    event LiquidityRemoved(
        address indexed provider,
        EGCT liquidityAmount,
        uint256[7] auditorPCT
    );

    /**
     * @notice Sets the auditor's public key for the pool
     */
    function setAuditorPublicKey(address user) external;

    /**
     * @notice Initializes the pool with initial liquidity
     */
    function initialize(
        EGCT memory amountA,
        EGCT memory amountB,
        uint256[7] memory liquidityPCT
    ) external;

    /**
     * @notice Performs a swap between the two tokens in the pool
     */
    function swap(
        address tokenIn,
        bool isExactInput,
        TransferProof memory proof,
        uint256[7] memory newBalancePCT
    ) external;

    /**
     * @notice Adds liquidity to the pool
     */
    function addLiquidity(
        EGCT memory amountA,
        EGCT memory amountB,
        uint256[7] memory liquidityPCT
    ) external;

    /**
     * @notice Removes liquidity from the pool
     */
    function removeLiquidity(
        EGCT memory liquidityAmount,
        uint256[7] memory newBalancePCT
    ) external;

    /**
     * @notice Gets the current reserves of the pool
     */
    function getReserves() external view returns (EGCT memory reserveA_, EGCT memory reserveB_);

    /**
     * @notice Gets the total supply of LP tokens
     */
    function getTotalSupply() external view returns (EGCT memory totalSupply_);
} 