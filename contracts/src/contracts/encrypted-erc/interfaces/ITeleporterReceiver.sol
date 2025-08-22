// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @dev Interface that describes the functionality for a contract to receive messages from ICM.
 */
interface ITeleporterReceiver {
    /**
     * @dev Called by TeleporterMessenger on the destination chain to deliver a message.
     * @param sourceBlockchainID The blockchain ID where the message originated
     * @param originSenderAddress The address that sent the original message
     * @param message The message payload
     */
    function receiveTeleporterMessage(
        bytes32 sourceBlockchainID,
        address originSenderAddress,
        bytes calldata message
    ) external;
} 