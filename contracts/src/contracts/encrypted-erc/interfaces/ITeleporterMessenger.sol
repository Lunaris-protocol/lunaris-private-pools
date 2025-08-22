// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @dev Struct for fee information
 */
struct TeleporterFeeInfo {
    address feeTokenAddress;
    uint256 amount;
}

/**
 * @dev Struct for message input
 */
struct TeleporterMessageInput {
    bytes32 destinationBlockchainID;
    address destinationAddress;
    TeleporterFeeInfo feeInfo;
    uint256 requiredGasLimit;
    address[] allowedRelayerAddresses;
    bytes message;
}

/**
 * @dev Interface that describes functionalities for a cross chain messenger.
 */
interface ITeleporterMessenger {
    /**
     * @dev Emitted when sending a interchain message cross chain.
     */
    event SendCrossChainMessage(
        uint256 indexed messageID,
        bytes32 indexed destinationBlockchainID,
        address indexed destinationAddress,
        TeleporterFeeInfo feeInfo
    );

    /**
     * @dev Called by transactions to initiate the sending of a cross L1 message.
     * @param messageInput The message input parameters
     * @return The message ID assigned to the message
     */
    function sendCrossChainMessage(TeleporterMessageInput calldata messageInput)
        external
        returns (uint256);

    /**
     * @dev Called by relayers to deliver a cross-chain message to the destination chain.
     * @param message The cross-chain message to be delivered
     */
    function receiveCrossChainMessage(bytes calldata message) external;
} 