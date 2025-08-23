// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EncryptedERC} from "../encrypted-erc/EncryptedERC.sol";
import {MintProof, BurnProof} from "../encrypted-erc/types/Types.sol";

/**
 * @title EncryptedERCRelayer
 * @notice Relayer contract that acts as owner of EncryptedERC and allows authorized contracts to mint/burn
 * @dev This contract solves the problem where EncryptedERC.privateMint is onlyOwner but we need
 *      multiple contracts (like SimpleHybridPool) to be able to trigger mints for users
 */
contract EncryptedERCRelayer is Ownable {
    /// @notice The EncryptedERC contract this relayer manages
    EncryptedERC public encryptedERC;

    /// @notice Mapping of contracts authorized to call relay functions
    mapping(address => bool) public authorizedCallers;

    /// @notice Events
    event CallerAuthorized(address indexed caller, bool authorized);
    event RelayedMint(address indexed user, address indexed caller);
    event RelayedBurn(address indexed user, address indexed caller);

    /// @notice Errors
    error NotAuthorized();
    error ZeroAddress();

    constructor(address _encryptedERC) Ownable(msg.sender) {
        if (_encryptedERC == address(0)) revert ZeroAddress();
        encryptedERC = EncryptedERC(_encryptedERC);
    }

    /**
     * @notice Authorize or deauthorize a contract to call relay functions
     * @param caller The contract address to authorize/deauthorize
     * @param authorized Whether to authorize or deauthorize
     */
    function setAuthorizedCaller(
        address caller,
        bool authorized
    ) external onlyOwner {
        if (caller == address(0)) revert ZeroAddress();
        authorizedCallers[caller] = authorized;
        emit CallerAuthorized(caller, authorized);
    }

    /**
     * @notice Relay a privateMint call to EncryptedERC
     * @param user The user to mint tokens for
     * @param proof The mint proof
     * @dev Only authorized callers can call this function
     */
    function relayPrivateMint(address user, MintProof calldata proof) external {
        if (!authorizedCallers[msg.sender]) revert NotAuthorized();

        // Call privateMint on EncryptedERC (we are the owner)
        encryptedERC.privateMint(user, proof);

        emit RelayedMint(user, msg.sender);
    }

    /**
     * @notice Relay a privateBurn call to EncryptedERC
     * @param proof The burn proof
     * @param balancePCT The balance PCT
     * @dev Only authorized callers can call this function
     * @dev Note: privateBurn uses msg.sender as the user, so we need to be careful here
     */
    function relayPrivateBurn(
        BurnProof calldata proof,
        uint256[7] calldata balancePCT
    ) external {
        if (!authorizedCallers[msg.sender]) revert NotAuthorized();

        // Call privateBurn on EncryptedERC (we are the owner)
        encryptedERC.privateBurn(proof, balancePCT);

        emit RelayedBurn(msg.sender, msg.sender);
    }

    /**
     * @notice Emergency function to transfer ownership of EncryptedERC
     * @param newOwner The new owner of the EncryptedERC contract
     */
    function transferEncryptedERCOwnership(
        address newOwner
    ) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        encryptedERC.transferOwnership(newOwner);
    }

    /**
     * @notice Set auditor public key on EncryptedERC
     * @param user The user to set as auditor
     */
    function setAuditorPublicKey(address user) external onlyOwner {
        encryptedERC.setAuditorPublicKey(user);
    }
}
