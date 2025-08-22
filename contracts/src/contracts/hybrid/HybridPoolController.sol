// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {IPrivacyPool} from "../../interfaces/IPrivacyPool.sol";
import {ProofLib} from "../lib/ProofLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title HybridPoolController
 * @notice SIMPLE controller that coordinates PrivacyPool deposits with EncryptedERC minting
 * @dev This is the SIMPLE version that just does:
 *      1. When user deposits → also mint EncryptedERC
 *      2. When user withdraws → also burn EncryptedERC
 */
contract HybridPoolController is Ownable {
    /// @notice The privacy pool contract
    IPrivacyPool public privacyPool;

    /// @notice The EncryptedERC contract
    IEncryptedERC public encryptedERC;

    /// @notice Whether hybrid functionality is enabled
    bool public hybridEnabled;

    /// @notice Mapping to track deposits for later burns
    mapping(address user => uint256 totalDeposited) public userDeposits;

    event DepositWithMint(
        address indexed user,
        uint256 poolCommitment,
        uint256 encryptedAmount
    );
    event WithdrawWithBurn(
        address indexed user,
        uint256 withdrawAmount,
        uint256 burnAmount
    );

    error HybridDisabled();
    error PrivacyPoolNotSet();
    error EncryptedERCNotSet();

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Set the privacy pool address
     */
    function setPrivacyPool(address _privacyPool) external onlyOwner {
        privacyPool = IPrivacyPool(_privacyPool);
    }

    /**
     * @notice Set the EncryptedERC address
     */
    function setEncryptedERC(address _encryptedERC) external onlyOwner {
        encryptedERC = IEncryptedERC(_encryptedERC);
    }

    /**
     * @notice Enable/disable hybrid functionality
     */
    function setHybridEnabled(bool _enabled) external onlyOwner {
        hybridEnabled = _enabled;
    }

    /**
     * @notice Deposit into privacy pool + mint EncryptedERC tokens
     * @param _value Amount to deposit
     * @param _precommitment Precommitment for privacy pool
     */
    function hybridDeposit(
        uint256 _value,
        uint256 _precommitment
    ) external payable returns (uint256 _commitment) {
        if (!hybridEnabled) revert HybridDisabled();
        if (address(privacyPool) == address(0)) revert PrivacyPoolNotSet();
        if (address(encryptedERC) == address(0)) revert EncryptedERCNotSet();

        // 1. Deposit into privacy pool
        _commitment = privacyPool.deposit{value: msg.value}(
            msg.sender,
            _value,
            _precommitment
        );

        // 2. Mint equivalent EncryptedERC tokens
        encryptedERC.mint(msg.sender, _value);

        // 3. Track user deposits
        userDeposits[msg.sender] += _value;

        emit DepositWithMint(msg.sender, _commitment, _value);
    }

    /**
     * @notice Withdraw from privacy pool + burn EncryptedERC tokens
     * @param _withdrawal Withdrawal data
     * @param _proof Privacy pool withdrawal proof
     * @param _burnAmount Amount of EncryptedERC to burn
     */
    function hybridWithdraw(
        IPrivacyPool.Withdrawal memory _withdrawal,
        ProofLib.WithdrawProof memory _proof,
        uint256 _burnAmount
    ) external {
        if (!hybridEnabled) revert HybridDisabled();
        if (address(privacyPool) == address(0)) revert PrivacyPoolNotSet();
        if (address(encryptedERC) == address(0)) revert EncryptedERCNotSet();

        // 1. Burn EncryptedERC tokens first
        encryptedERC.burn(msg.sender, _burnAmount);

        // 2. Proceed with privacy pool withdrawal
        privacyPool.withdraw(_withdrawal, _proof);

        // 3. Update tracking
        userDeposits[msg.sender] -= _burnAmount;

        emit WithdrawWithBurn(
            msg.sender,
            _proof.pubSignals[2], // withdrawnValue is at index 2
            _burnAmount
        );
    }

    /**
     * @notice Standard privacy pool deposit (no EncryptedERC minting)
     */
    function standardDeposit(
        uint256 _value,
        uint256 _precommitment
    ) external payable returns (uint256 _commitment) {
        if (address(privacyPool) == address(0)) revert PrivacyPoolNotSet();

        return
            privacyPool.deposit{value: msg.value}(
                msg.sender,
                _value,
                _precommitment
            );
    }

    /**
     * @notice Standard privacy pool withdraw (no EncryptedERC burning)
     */
    function standardWithdraw(
        IPrivacyPool.Withdrawal memory _withdrawal,
        ProofLib.WithdrawProof memory _proof
    ) external {
        if (address(privacyPool) == address(0)) revert PrivacyPoolNotSet();

        privacyPool.withdraw(_withdrawal, _proof);
    }
}

// Simple interface for EncryptedERC (just what we need)
interface IEncryptedERC {
    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}

// Already imported above
