// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {IPrivacyPool} from "../../interfaces/core/IPrivacyPool.sol";
import {ProofLib} from "libraries/ProofLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title HybridPoolController
 * @notice SIMPLE controller that coordinates PrivacyPool deposits with EncryptedERC minting
 * @dev This controller acts as a coordinator but the actual hybrid logic
 *      should be implemented in the SimpleHybridPool contract itself.
 *      This controller is for cases where you want to use separate contracts.
 */
contract HybridPoolController is Ownable {
    /// @notice The privacy pool contract
    IPrivacyPool public privacyPool;

    /// @notice Whether hybrid functionality is enabled
    bool public hybridEnabled;

    event StandardDeposit(address indexed user, uint256 poolCommitment);
    event StandardWithdraw(address indexed user, uint256 withdrawAmount);

    error HybridDisabled();
    error PrivacyPoolNotSet();

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Set the privacy pool address
     */
    function setPrivacyPool(address _privacyPool) external onlyOwner {
        privacyPool = IPrivacyPool(_privacyPool);
    }

    /**
     * @notice Enable/disable hybrid functionality
     */
    function setHybridEnabled(bool _enabled) external onlyOwner {
        hybridEnabled = _enabled;
    }

    /**
     * @notice Standard privacy pool deposit
     */
    function standardDeposit(
        uint256 _value,
        uint256 _precommitment
    ) external payable returns (uint256 _commitment) {
        if (address(privacyPool) == address(0)) revert PrivacyPoolNotSet();

        _commitment = privacyPool.deposit{value: msg.value}(
            msg.sender,
            _value,
            _precommitment
        );

        emit StandardDeposit(msg.sender, _commitment);
    }

    /**
     * @notice Standard privacy pool withdraw
     */
    function standardWithdraw(
        IPrivacyPool.Withdrawal memory _withdrawal,
        ProofLib.WithdrawProof memory _proof
    ) external {
        if (address(privacyPool) == address(0)) revert PrivacyPoolNotSet();

        privacyPool.withdraw(_withdrawal, _proof);

        emit StandardWithdraw(msg.sender, ProofLib.withdrawnValue(_proof));
    }
}
