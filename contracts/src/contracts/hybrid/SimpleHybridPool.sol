// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {PrivacyPool} from "../PrivacyPool.sol";
import {ProofLib} from "../lib/ProofLib.sol";
import {Constants} from "../lib/Constants.sol";
import {PoseidonT4} from "poseidon/PoseidonT4.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IEncryptedERC {
    function privateMint(
        address user,
        MintProof calldata proof,
        bytes calldata message
    ) external;

    function privateBurn(
        BurnProof calldata proof,
        uint256[7] calldata balancePCT
    ) external;
}

// Minimum required types
struct MintProof {
    ProofPoints proofPoints;
    uint256[24] publicSignals;
}

struct BurnProof {
    ProofPoints proofPoints;
    uint256[19] publicSignals;
}

struct ProofPoints {
    uint256[2] a;
    uint256[2][2] b;
    uint256[2] c;
}

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

    /// @notice El contrato EncryptedERC
    IEncryptedERC public encryptedERC;

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
        address _encryptedERC
    ) PrivacyPool(_entrypoint, _withdrawalVerifier, _ragequitVerifier, _asset) {
        encryptedERC = IEncryptedERC(_encryptedERC);
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

        // 2. IF HYBRID ENABLED: MINT ENCRYPTEDERC
        if (hybridEnabled && address(encryptedERC) != address(0)) {
            try encryptedERC.privateMint(_depositor, _mintProof, "") {
                emit HybridDeposit(_depositor, _commitment, _value);
            } catch {
                revert InvalidProof();
            }
        }

        return _commitment;
    }

    /**
     * @notice Withdraw from pool + burn EncryptedERC if enabled
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

        uint256 withdrawnAmount = _poolProof.pubSignals[2]; // withdrawnValue

        // 2. IF HYBRID ENABLED: BURN ENCRYPTEDERC FIRST
        if (hybridEnabled && address(encryptedERC) != address(0)) {
            // The user MUST provide a valid burn proof
            encryptedERC.privateBurn(_burnProof, _balancePCT);
            emit HybridWithdraw(msg.sender, withdrawnAmount);
        }

        // 3. PROCEED WITH NORMAL PRIVACY POOL WITHDRAWAL
        _spend(_poolProof.pubSignals[1]); // existingNullifierHash
        _insert(_poolProof.pubSignals[0]); // newCommitmentHash
        _push(_withdrawal.processooor, withdrawnAmount);

        emit Withdrawn(
            _withdrawal.processooor,
            withdrawnAmount,
            _poolProof.pubSignals[1], // spentNullifier
            _poolProof.pubSignals[0] // newCommitment
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
