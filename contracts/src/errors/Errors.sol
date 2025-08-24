// (c) 2025, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

// SPDX-License-Identifier: Ecosystem

pragma solidity 0.8.28;

/*///////////////////////////////////////////////////////////////
                    GENERAL ERRORS
//////////////////////////////////////////////////////////////*/

/// @notice Thrown when an address parameter is zero
error ZeroAddress();

/// @notice Thrown when trying to perform an unauthorized operation
error UnauthorizedAccess();

/// @notice Thrown when an invalid operation is attempted
error InvalidOperation();

/// @notice Thrown when a transfer operation fails
error TransferFailed();

/// @notice Thrown when the chain ID is invalid
error InvalidChainId();

/*///////////////////////////////////////////////////////////////
                    USER & REGISTRATION ERRORS
//////////////////////////////////////////////////////////////*/

/// @notice Thrown when a user is already registered
error UserAlreadyRegistered();

/// @notice Thrown when a user is not registered
error UserNotRegistered();

/// @notice Thrown when the sender is invalid for the operation
error InvalidSender();

/// @notice Thrown when a registration hash is invalid
error InvalidRegistrationHash();

/*///////////////////////////////////////////////////////////////
                    PROOF & VERIFICATION ERRORS
//////////////////////////////////////////////////////////////*/

/// @notice Thrown when a zero-knowledge proof is invalid
error InvalidProof();

/// @notice Thrown when a nullifier is invalid
error InvalidNullifier();

/*///////////////////////////////////////////////////////////////
                    AUDITOR ERRORS
//////////////////////////////////////////////////////////////*/

/// @notice Thrown when the auditor key is not set
error AuditorKeyNotSet();

/*///////////////////////////////////////////////////////////////
                    TOKEN & BALANCE ERRORS
//////////////////////////////////////////////////////////////*/

/// @notice Thrown when a token is unknown
error UnknownToken();

/// @notice Thrown when a token is blacklisted
/// @param token The address of the blacklisted token
error TokenBlacklisted(address token);

/*///////////////////////////////////////////////////////////////
                    LIQUIDITY & SWAP ERRORS
//////////////////////////////////////////////////////////////*/

/// @notice Thrown when there is insufficient liquidity
error InsufficientLiquidity();

/// @notice Thrown when a swap amount is invalid
error InvalidSwapAmount();

/// @notice Thrown when slippage tolerance is exceeded
error SlippageExceeded();
