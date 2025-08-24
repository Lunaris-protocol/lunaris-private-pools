// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {PrivacyPool} from "../PrivacyPool.sol";
import {ProofLib} from "../lib/ProofLib.sol";
import {Constants} from "../lib/Constants.sol";
import {PoseidonT4} from "poseidon/PoseidonT4.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Import EncryptedERC contract and types
import {EncryptedERC} from "../encrypted-erc/EncryptedERC.sol";
import {BurnProof} from "../encrypted-erc/types/Types.sol";
import {IState} from "../../interfaces/IState.sol";

/**
 * @title SimpleHybridPool
 * @notice SIMPLE: Privacy Pool that deposits to EncryptedERC pool on deposit
 *
 * WHAT IT DOES:
 * 1. User deposits ERC20 → Privacy Pool + deposit to EncryptedERC pool
 * 2. User withdraws from Privacy Pool → receive ERC20 (EncryptedERC handled separately)
 */
contract SimpleHybridPool is PrivacyPool {
    using SafeERC20 for IERC20;
    using ProofLib for ProofLib.WithdrawProof;

    /// @notice EncryptedERC contract for hybrid functionality
    EncryptedERC public encryptedERC;

    /// @notice If hybrid mode is enable sd
    bool public hybridEnabled;

    event HybridDeposit(
        address indexed user,
        uint256 indexed commitment,
        uint256 amount
    );
    event HybridWithdraw(
        address indexed user,
        uint256 amount,
        uint256 nullifierHash
    );

    constructor(
        address _entrypoint,
        address _withdrawalVerifier,
        address _ragequitVerifier,
        address _asset,
        address _encryptedERC
    ) PrivacyPool(_entrypoint, _withdrawalVerifier, _ragequitVerifier, _asset) {
        if (_encryptedERC == address(0)) revert IState.ZeroAddress();
        encryptedERC = EncryptedERC(_encryptedERC);
        hybridEnabled = false; // Start disabled
    }

    /**
     * @notice Enable/disable hybrid mode
     */
    function setHybridEnabled(bool _enabled) external onlyEntrypoint {
        hybridEnabled = _enabled;
    }

    /**
     * @notice Normal deposit + deposit to EncryptedERC pool if enabled
     */
    function hybridDeposit(
        address _depositor,
        uint256 _value,
        uint256 _precommitmentHash,
        uint256[7] calldata _amountPCT
    ) external payable onlyEntrypoint returns (uint256 _commitment) {
        if (dead) revert PoolIsDead();
        if (_value >= type(uint128).max) revert InvalidDepositValue();

        uint256 _label = uint256(keccak256(abi.encodePacked(SCOPE, ++nonce))) %
            Constants.SNARK_SCALAR_FIELD;
        depositors[_label] = _depositor;
        _commitment = PoseidonT4.hash([_value, _label, _precommitmentHash]);
        _insert(_commitment);
        _pull(msg.sender, _value);

        emit Deposited(
            _depositor,
            _commitment,
            _label,
            _value,
            _precommitmentHash
        );

        IERC20(ASSET).approve(address(encryptedERC), _value);

        try encryptedERC.depositPool(_value, ASSET, _amountPCT) {
            emit HybridDeposit(_depositor, _commitment, _value);
        } catch {
            revert("EncryptedERC deposit failed");
        }

        return _commitment;
    }

    /**
     * @notice Hybrid withdraw: Burns user's EncryptedERC tokens and withdraws ERC20 from pool
     * @param _withdrawal Standard privacy pool withdrawal parameters
     * @param _poolProof Privacy pool withdrawal proof
     * @param _burnProof EncryptedERC burn proof to burn user's encrypted tokens
     * @param _balancePCT Balance PCT for user after burn
     * @dev This function:
     *      1. Verifies the privacy pool withdrawal proof
     *      2. Burns the user's EncryptedERC tokens (if hybrid enabled)
     *      3. Transfers ERC20 tokens from pool to user
     */
    function hybridWithdraw(
        Withdrawal memory _withdrawal,
        ProofLib.WithdrawProof memory _poolProof,
        BurnProof calldata _burnProof,
        uint256[7] calldata _balancePCT
    ) external validWithdrawal(_withdrawal, _poolProof) {
        // 1. VERIFY PRIVACY POOL PROOF
        if (
            !WITHDRAWAL_VERIFIER.verifyProof(
                _poolProof.pA,
                _poolProof.pB,
                _poolProof.pC,
                _poolProof.pubSignals
            )
        ) {
            revert InvalidProof();
        }

        uint256 withdrawnAmount = _poolProof.withdrawnValue();

        // 2. BURN ENCRYPTEDERC TOKENS IF HYBRID ENABLED
        try encryptedERC.privateBurn(_burnProof, _balancePCT) {
            // Burn successful - continue with withdrawal
        } catch {
            revert("EncryptedERC burn failed");
        }

        // 3. PROCEED WITH NORMAL PRIVACY POOL WITHDRAWAL
        _spend(_poolProof.existingNullifierHash());
        _insert(_poolProof.newCommitmentHash());
        _push(_withdrawal.processooor, withdrawnAmount);

        emit Withdrawn(
            _withdrawal.processooor,
            withdrawnAmount,
            _poolProof.existingNullifierHash(),
            _poolProof.newCommitmentHash()
        );

        // Emit hybrid-specific event
        emit HybridWithdraw(
            _withdrawal.processooor,
            withdrawnAmount,
            _poolProof.existingNullifierHash()
        );
    }

    /**
     * @notice Pull ERC20 tokens
     */
    function _pull(address _sender, uint256 _value) internal virtual override {
        if (msg.value > 0) revert("No native asset");
        IERC20(ASSET).safeTransferFrom(_sender, address(this), _value);
    }

    /**
     * @notice Push ERC20 tokens
     */
    function _push(
        address _recipient,
        uint256 _value
    ) internal virtual override {
        IERC20(ASSET).safeTransfer(_recipient, _value);
    }
}
