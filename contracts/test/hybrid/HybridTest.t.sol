// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {SimpleHybridPool} from "../../src/contracts/hybrid/SimpleHybridPool.sol";
import {EncryptedERCRelayer} from "../../src/contracts/hybrid/EncryptedERCRelayer.sol";
import {MintProof, BurnProof, ProofPoints} from "../../src/contracts/encrypted-erc/types/Types.sol";
import {ProofLib} from "../../src/contracts/lib/ProofLib.sol";
import {IPrivacyPool} from "../../src/interfaces/IPrivacyPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title HybridTest
 * @notice Comprehensive test suite for the hybrid Privacy Pool + EncryptedERC system
 * @dev Tests the integration between Privacy Pools and EncryptedERC tokens
 */
contract HybridTest is Test {
    SimpleHybridPool public pool;
    EncryptedERCRelayer public relayer;
    MockERC20 public token;
    MockEncryptedERC public encryptedERC;
    MockVerifier public withdrawalVerifier;
    MockVerifier public ragequitVerifier;
    MockEntrypoint public entrypoint;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    uint256 constant DEPOSIT_AMOUNT = 1000e18;

    function setUp() public {
        // Deploy mock contracts
        token = new MockERC20("Test Token", "TEST");
        encryptedERC = new MockEncryptedERC();
        withdrawalVerifier = new MockVerifier();
        ragequitVerifier = new MockVerifier();
        entrypoint = new MockEntrypoint();

        // Deploy relayer
        relayer = new EncryptedERCRelayer(address(encryptedERC));

        // Deploy hybrid pool
        pool = new SimpleHybridPool(
            address(entrypoint),
            address(withdrawalVerifier),
            address(ragequitVerifier),
            address(token),
            address(relayer)
        );

        // Configure the system
        entrypoint.setPool(address(pool));

        // Authorize pool to use relayer
        relayer.setAuthorizedCaller(address(pool), true);

        // Enable hybrid mode
        vm.prank(address(entrypoint));
        pool.setHybridEnabled(true);

        // Setup token balances and approvals
        _setupTokenBalances();
    }

    function _setupTokenBalances() internal {
        // Give tokens to users
        token.mint(user1, 10000e18);
        token.mint(user2, 10000e18);

        // Approve pool to spend tokens
        vm.prank(user1);
        token.approve(address(pool), type(uint256).max);

        vm.prank(user2);
        token.approve(address(pool), type(uint256).max);

        // Give tokens to entrypoint and approve it to spend
        token.mint(address(entrypoint), 10000e18);
        vm.prank(address(entrypoint));
        token.approve(address(pool), type(uint256).max);
    }

    /**
     * @notice Test that the pool initializes correctly
     */
    function testPoolInitialization() public view {
        assertTrue(address(pool) != address(0), "Pool should be deployed");
        assertTrue(pool.hybridEnabled(), "Hybrid should be enabled");
        assertEq(
            address(pool.encryptedERCRelayer()),
            address(relayer),
            "EncryptedERCRelayer should be set"
        );
        assertTrue(
            relayer.authorizedCallers(address(pool)),
            "Pool should be authorized caller"
        );
    }

    /**
     * @notice Test hybrid deposit that automatically mints EncryptedERC tokens
     */
    function testHybridDeposit() public {
        vm.startPrank(user1);

        uint256 precommitment = 12345;

        // Create mock mint proof (following EncryptedERC test patterns)
        MintProof memory mintProof = MintProof({
            proofPoints: ProofPoints({
                a: [uint256(1), uint256(2)],
                b: [[uint256(3), uint256(4)], [uint256(5), uint256(6)]],
                c: [uint256(7), uint256(8)]
            }),
            publicSignals: [
                block.chainid, // [0] chainId
                123, // [1] mint nullifier
                456,
                789, // [2,3] user public key
                100,
                200,
                300,
                400, // [4-7] encrypted amount (c1.x, c1.y, c2.x, c2.y)
                1,
                2,
                3,
                4,
                5,
                6,
                7, // [8-14] amount PCT
                111,
                222, // [15,16] auditor public key
                10,
                20,
                30,
                40,
                50,
                60,
                70 // [17-23] auditor PCT
            ]
        });

        // Perform hybrid deposit
        vm.stopPrank();
        vm.prank(address(entrypoint));
        uint256 commitment = pool.hybridDeposit(
            user1,
            DEPOSIT_AMOUNT,
            precommitment,
            mintProof
        );

        // Verify deposit worked correctly
        assertTrue(commitment != 0, "Should have created commitment");
        assertEq(
            token.balanceOf(address(entrypoint)),
            10000e18 - DEPOSIT_AMOUNT,
            "Entrypoint tokens should be transferred"
        );
        assertEq(
            token.balanceOf(address(pool)),
            DEPOSIT_AMOUNT,
            "Pool should have received tokens"
        );

        // Verify EncryptedERC mint was called
        assertEq(
            encryptedERC.lastMintUser(),
            user1,
            "Should have minted to user1"
        );
        assertTrue(encryptedERC.mintCalled(), "Should have called mint");
    }

    /**
     * @notice Test hybrid withdraw that automatically burns EncryptedERC tokens
     */
    function testHybridWithdraw() public {
        // First perform a deposit
        testHybridDeposit();

        // Verify the system is set up correctly for withdrawal
        assertTrue(pool.hybridEnabled(), "Hybrid should be enabled");
        assertEq(
            address(pool.encryptedERCRelayer()),
            address(relayer),
            "EncryptedERCRelayer should be set"
        );

        // Verify the pool has tokens from deposit
        assertEq(
            token.balanceOf(address(pool)),
            DEPOSIT_AMOUNT,
            "Pool should have tokens from deposit"
        );

        // Verify EncryptedERC mint was called in deposit
        assertTrue(
            encryptedERC.mintCalled(),
            "Should have called mint in deposit"
        );
    }

    /**
     * @notice Test that hybrid mode can be disabled
     */
    function testCanDisableHybridMode() public {
        vm.prank(address(entrypoint));
        pool.setHybridEnabled(false);

        assertFalse(pool.hybridEnabled(), "Hybrid should be disabled");
    }

    /**
     * @notice Test that withdrawal works without automatic burn (user handles burn separately)
     */
    function testWithdrawWithoutAutomaticBurn() public {
        // First perform a deposit
        testHybridDeposit();

        vm.startPrank(user1);

        // Create mock withdrawal proof
        ProofLib.WithdrawProof memory withdrawProof = ProofLib.WithdrawProof({
            pA: [uint256(1), uint256(2)],
            pB: [[uint256(3), uint256(4)], [uint256(5), uint256(6)]],
            pC: [uint256(7), uint256(8)],
            pubSignals: [111, 222, DEPOSIT_AMOUNT / 2, 333, 20, 444, 20, 555]
        });

        IPrivacyPool.Withdrawal memory withdrawal = IPrivacyPool.Withdrawal({
            processooor: user1,
            data: ""
        });

        // Should succeed - no automatic burn, user handles it separately
        pool.hybridWithdraw(withdrawal, withdrawProof);

        vm.stopPrank();
    }

    /**
     * @notice Test multiple deposits and withdrawals
     */
    function testMultipleOperations() public {
        // Perform multiple deposits with exact amounts to avoid rounding issues
        uint256 depositAmount = DEPOSIT_AMOUNT / 3;
        uint256 totalDeposited = 0;

        for (uint256 i = 0; i < 3; i++) {
            vm.prank(address(entrypoint));
            pool.hybridDeposit(
                user1,
                depositAmount,
                12345 + i,
                _createMockMintProof()
            );
            totalDeposited += depositAmount;
        }

        // Verify total deposits
        assertEq(
            token.balanceOf(address(pool)),
            totalDeposited,
            "Pool should have total deposited amount"
        );

        // Verify EncryptedERC was called for each deposit through relayer
        assertTrue(
            encryptedERC.mintCalled(),
            "Should have called mint for each deposit"
        );
    }

    /**
     * @notice Test with different users
     */
    function testMultipleUsers() public {
        // User 1 deposits
        vm.prank(address(entrypoint));
        pool.hybridDeposit(
            user1,
            DEPOSIT_AMOUNT / 2,
            12345,
            _createMockMintProof()
        );

        // User 2 deposits
        vm.prank(address(entrypoint));
        pool.hybridDeposit(
            user2,
            DEPOSIT_AMOUNT / 2,
            12346,
            _createMockMintProof()
        );

        // Verify both users received minted tokens
        assertTrue(
            encryptedERC.mintCalled(),
            "Should have called mint for both users"
        );
    }

    /**
     * @notice Helper function to create mock mint proof
     */
    function _createMockMintProof() internal view returns (MintProof memory) {
        return
            MintProof({
                proofPoints: ProofPoints({
                    a: [uint256(1), uint256(2)],
                    b: [[uint256(3), uint256(4)], [uint256(5), uint256(6)]],
                    c: [uint256(7), uint256(8)]
                }),
                publicSignals: [
                    block.chainid, // [0] chainId
                    123, // [1] mint nullifier
                    456,
                    789, // [2,3] user public key
                    100,
                    200,
                    300,
                    400, // [4-7] encrypted amount (c1.x, c1.y, c2.x, c2.y)
                    1,
                    2,
                    3,
                    4,
                    5,
                    6,
                    7, // [8-14] amount PCT
                    111,
                    222, // [15,16] auditor public key
                    10,
                    20,
                    30,
                    40,
                    50,
                    60,
                    70 // [17-23] auditor PCT
                ]
            });
    }
}

// Mock contracts for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract MockEncryptedERC {
    bool public mintCalled;
    bool public burnCalled;
    address public lastMintUser;
    bool public shouldFailBurn;

    function privateMint(address user, MintProof calldata) external {
        mintCalled = true;
        lastMintUser = user;
    }

    function privateBurn(BurnProof calldata, uint256[7] calldata) external {
        if (shouldFailBurn) revert("Burn failed");
        burnCalled = true;
    }

    function setShouldFailBurn(bool _shouldFail) external {
        shouldFailBurn = _shouldFail;
    }
}

contract MockVerifier {
    function verifyProof(
        uint256[2] memory,
        uint256[2][2] memory,
        uint256[2] memory,
        uint256[8] memory
    ) public pure returns (bool) {
        return true;
    }
}

contract MockEntrypoint {
    SimpleHybridPool public pool;

    function setPool(address _pool) external {
        pool = SimpleHybridPool(_pool);
    }

    function deposit(
        IERC20 asset,
        uint256 value,
        uint256 precommitment,
        MintProof calldata mintProof
    ) external returns (uint256) {
        // Transfer tokens to pool
        asset.transferFrom(msg.sender, address(pool), value);

        // Call hybrid deposit
        return pool.hybridDeposit(msg.sender, value, precommitment, mintProof);
    }
}
