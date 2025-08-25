// SPDX-License-Identifier: Ecosystem
pragma solidity 0.8.28;

import {Metadata} from "../../../types/Types.sol";

/**
 * @title EncryptedMetadata
 * @notice Simple metadata functionality for encrypted operations
 */
contract EncryptedMetadata {
    event PrivateMessage(
        address indexed from,
        address indexed to,
        Metadata metadata
    );

    function _sendEncryptedMetadata(
        address to,
        bytes calldata message
    ) internal {
        address messageFrom = msg.sender;
        Metadata memory metadata = _createMetadata(
            messageFrom,
            to,
            "MESSAGE",
            message
        );
        emit PrivateMessage(messageFrom, to, metadata);
    }

    function _emitMetadata(
        address from,
        address to,
        string memory messageType,
        bytes memory message
    ) internal {
        if (message.length > 0) {
            Metadata memory metadata = _createMetadata(
                from,
                to,
                messageType,
                message
            );
            emit PrivateMessage(from, to, metadata);
        }
    }

    function _createMetadata(
        address messageFrom,
        address messageTo,
        string memory messageType,
        bytes memory encryptedMsg
    ) internal pure returns (Metadata memory metadata) {
        metadata.messageFrom = messageFrom;
        metadata.messageTo = messageTo;
        metadata.messageType = messageType;
        metadata.encryptedMsg = encryptedMsg;
        return metadata;
    }
}
