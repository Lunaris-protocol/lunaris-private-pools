// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {PrivacyPool} from "../PrivacyPool.sol";
import {ProofLib} from "../lib/ProofLib.sol";
import {Constants} from "../lib/Constants.sol";
import {PoseidonT4} from "poseidon/PoseidonT4.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Import types from EncryptedERC
import {MintProof, BurnProof} from "../encrypted-erc/types/Types.sol";
// Import the relayer contract
import {EncryptedERCRelayer} from "./EncryptedERCRelayer.sol";

/**
 * @title SimpleHybridPool
 * @notice SIMPLE: Privacy Pool that mints EncryptedERC on deposit and burns on withdraw
 *
 * WHAT IT DOES:
 * 1. User deposits ERC20 → Privacy Pool + mint EncryptedERC
 * 2. User withdraws from Privacy Pool → burn EncryptedERC + receive ERC20
 */
contract SimpleHybridPool is PrivacyPool {
    using SafeERC20 for IERC20;

    /// @notice El relayer para EncryptedERC
    EncryptedERCRelayer public encryptedERCRelayer;

    /// @notice If hybrid mode is enabled
    bool public hybridEnabled;

    event HybridDeposit(
        address indexed user,
        uint256 indexed commitment,
        uint256 amount
    );
    event HybridWithdraw(address indexed user, uint256 amount);

    constructor(
        address _entrypoint,
        address _withdrawalVerifier,
        address _ragequitVerifier,
        address _asset,
        address _encryptedERCRelayer
    ) PrivacyPool(_entrypoint, _withdrawalVerifier, _ragequitVerifier, _asset) {
        encryptedERCRelayer = EncryptedERCRelayer(_encryptedERCRelayer);
        hybridEnabled = false; // Start disabled
    }

    /**
     * @notice Enable/disable hybrid mode
     */
    function setHybridEnabled(bool _enabled) external onlyEntrypoint {
        hybridEnabled = _enabled;
    }

    /**
     * @notice Normal deposit + mint EncryptedERC if enabled
     */
    function hybridDeposit(
        address _depositor,
        uint256 _value,
        uint256 _precommitmentHash,
        MintProof calldata _mintProof
    ) external payable onlyEntrypoint returns (uint256 _commitment) {
        // 1. PERFORM NORMAL DEPOSIT IN PRIVACY POOL
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

        // 2. MINT ENCRYPTEDERC IF HYBRID ENABLED
        if (hybridEnabled && address(encryptedERCRelayer) != address(0)) {
            try encryptedERCRelayer.relayPrivateMint(_depositor, _mintProof) {
                emit HybridDeposit(_depositor, _commitment, _value);
            } catch {
                revert InvalidProof();
            }
        }

        return _commitment;
    }

    /**
     * @notice Withdraw from pool (user must burn EncryptedERC separately if hybrid enabled)
     * @dev For hybrid mode: User should call EncryptedERC.privateBurn() BEFORE calling this function
     */
    function hybridWithdraw(
        Withdrawal memory _withdrawal,
        ProofLib.WithdrawProof memory _poolProof
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

        // 2. PROCEED WITH NORMAL PRIVACY POOL WITHDRAWAL
        _spend(_poolProof.existingNullifierHash());
        _insert(_poolProof.newCommitmentHash());
        _push(_withdrawal.processooor, withdrawnAmount);

        emit Withdrawn(
            _withdrawal.processooor,
            withdrawnAmount,
            _poolProof.existingNullifierHash(),
            _poolProof.newCommitmentHash()
        );
    }

    /**
     * @notice Pull ERC20 tokens
     */
    function _pull(address _sender, uint256 _value) internal override {
        if (msg.value > 0) revert("No native asset");
        IERC20(ASSET).safeTransferFrom(_sender, address(this), _value);
    }

    /**
     * @notice Push ERC20 tokens
     */
    function _push(address _recipient, uint256 _value) internal override {
        IERC20(ASSET).safeTransfer(_recipient, _value);
    }
}
