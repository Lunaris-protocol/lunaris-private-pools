// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

import {Constants} from "../../src/libraries/Constants.sol";
import {Point, EGCT, ProofPoints} from "../../src/types/Types.sol";

/**
 * @title TestHelpers
 * @notice Common helper functions and utilities for tests
 */
contract TestHelpers is Test {
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant SNARK_SCALAR_FIELD = Constants.SNARK_SCALAR_FIELD;
    address public constant NATIVE_ASSET = Constants.NATIVE_ASSET;

    /*//////////////////////////////////////////////////////////////
                            COMMON ADDRESSES
    //////////////////////////////////////////////////////////////*/

    address internal immutable OWNER = makeAddr("OWNER");
    address internal immutable ALICE = makeAddr("ALICE");
    address internal immutable BOB = makeAddr("BOB");
    address internal immutable CHARLIE = makeAddr("CHARLIE");
    address internal immutable RELAYER = makeAddr("RELAYER");
    address internal immutable AUDITOR = makeAddr("AUDITOR");

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Assumes address is fuzzable (not forge, zero, or precompile)
     */
    function assumeFuzzable(address addr) internal pure {
        assumeNotForgeAddress(addr);
        assumeNotZeroAddress(addr);
        assumeNotPrecompile(addr);
    }

    /**
     * @notice Bounds a value to be within the SNARK scalar field
     */
    function boundToScalarField(uint256 value) internal pure returns (uint256) {
        return bound(value, 1, SNARK_SCALAR_FIELD - 1);
    }

    /**
     * @notice Creates a mock Point with given coordinates
     */
    function createMockPoint(
        uint256 x,
        uint256 y
    ) internal pure returns (Point memory) {
        return Point({x: x, y: y});
    }

    /**
     * @notice Creates a mock EGCT with given points
     */
    function createMockEGCT(
        uint256 c1x,
        uint256 c1y,
        uint256 c2x,
        uint256 c2y
    ) internal pure returns (EGCT memory) {
        return EGCT({c1: Point({x: c1x, y: c1y}), c2: Point({x: c2x, y: c2y})});
    }

    /**
     * @notice Creates mock ProofPoints for testing
     */
    function createMockProofPoints()
        internal
        pure
        returns (ProofPoints memory)
    {
        return
            ProofPoints({
                a: [uint256(1), uint256(2)],
                b: [[uint256(3), uint256(4)], [uint256(5), uint256(6)]],
                c: [uint256(7), uint256(8)]
            });
    }

    /**
     * @notice Creates a mock public key array
     */
    function createMockPublicKey(
        uint256 x,
        uint256 y
    ) internal pure returns (uint256[2] memory) {
        return [x, y];
    }

    /**
     * @notice Creates a mock amount PCT array with incremental values
     */
    function createMockAmountPCT(
        uint256 base
    ) internal pure returns (uint256[7] memory) {
        return [
            base,
            base + 10,
            base + 20,
            base + 30,
            base + 40,
            base + 50,
            base + 60
        ];
    }

    /**
     * @notice Mocks a call with any arguments to return a boolean
     */
    function mockCallWithBool(
        address target,
        bytes4 selector,
        bool returnValue
    ) internal {
        vm.mockCall(
            target,
            abi.encodeWithSelector(selector),
            abi.encode(returnValue)
        );
    }

    /**
     * @notice Mocks a verifier to always return the given result
     */
    function mockVerifier(address verifier, bool result) internal {
        vm.mockCall(
            verifier,
            abi.encodeWithSignature(
                "verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[])"
            ),
            abi.encode(result)
        );
    }

    /**
     * @notice Deals ERC20 tokens to an address
     */
    function dealERC20(address token, address to, uint256 amount) internal {
        deal(token, to, amount);
    }

    /**
     * @notice Deals native asset to an address
     */
    function dealNative(address to, uint256 amount) internal {
        deal(to, amount);
    }

    /**
     * @notice Gets the balance of an asset (native or ERC20)
     */
    function getBalance(
        address asset,
        address account
    ) internal view returns (uint256) {
        if (asset == NATIVE_ASSET) {
            return account.balance;
        } else {
            return IERC20(asset).balanceOf(account);
        }
    }

    /**
     * @notice Calculates fee amount based on basis points
     */
    function calculateFee(
        uint256 amount,
        uint256 feeBPS
    ) internal pure returns (uint256) {
        return (amount * feeBPS) / 10000;
    }

    /**
     * @notice Calculates amount after deducting fee
     */
    function afterFee(
        uint256 amount,
        uint256 feeBPS
    ) internal pure returns (uint256) {
        return amount - calculateFee(amount, feeBPS);
    }

    /**
     * @notice Generates a pseudo-random secret based on a seed
     */
    function generateSecret(uint256 seed) internal pure returns (uint256) {
        return
            uint256(keccak256(abi.encodePacked(seed, "SECRET"))) %
            SNARK_SCALAR_FIELD;
    }

    /**
     * @notice Generates a pseudo-random nullifier based on a seed
     */
    function generateNullifier(uint256 seed) internal pure returns (uint256) {
        return
            uint256(keccak256(abi.encodePacked(seed, "NULLIFIER"))) %
            SNARK_SCALAR_FIELD;
    }

    /**
     * @notice Logs test information for debugging
     */
    function logTestInfo(string memory testName) internal {
        console.log("=== Running Test:", testName, "===");
        console.log("Block number:", block.number);
        console.log("Block timestamp:", block.timestamp);
        console.log("Chain ID:", block.chainid);
    }

    /**
     * @notice Asserts that two Points are equal
     */
    function assertEqPoint(
        Point memory a,
        Point memory b,
        string memory err
    ) internal {
        assertEq(a.x, b.x, string.concat(err, ": x coordinate mismatch"));
        assertEq(a.y, b.y, string.concat(err, ": y coordinate mismatch"));
    }

    /**
     * @notice Asserts that two EGCT structures are equal
     */
    function assertEqEGCT(
        EGCT memory a,
        EGCT memory b,
        string memory err
    ) internal {
        assertEqPoint(a.c1, b.c1, string.concat(err, ": c1 mismatch"));
        assertEqPoint(a.c2, b.c2, string.concat(err, ": c2 mismatch"));
    }

    /**
     * @notice Asserts that a Point is not zero
     */
    function assertNonZeroPoint(
        Point memory point,
        string memory err
    ) internal {
        assertTrue(
            point.x != 0 || point.y != 0,
            string.concat(err, ": Point is zero")
        );
    }

    /**
     * @notice Asserts that an EGCT is not zero
     */
    function assertNonZeroEGCT(EGCT memory eGCT, string memory err) internal {
        bool isZero = (eGCT.c1.x == 0 &&
            eGCT.c1.y == 0 &&
            eGCT.c2.x == 0 &&
            eGCT.c2.y == 0);
        assertFalse(isZero, string.concat(err, ": EGCT is zero"));
    }

    /**
     * @notice Skip test if condition is not met
     */
    function skipIf(bool condition, string memory reason) internal {
        if (condition) {
            console.log("SKIPPING TEST:", reason);
            vm.skip(true);
        }
    }

    /**
     * @notice Set up common test environment
     */
    function setUpCommon() internal {
        // Set up reasonable block parameters
        vm.warp(1_700_000_000); // Set timestamp to a reasonable value
        vm.roll(19_000_000); // Set block number to a reasonable value

        // Label important addresses for better trace output
        vm.label(OWNER, "OWNER");
        vm.label(ALICE, "ALICE");
        vm.label(BOB, "BOB");
        vm.label(CHARLIE, "CHARLIE");
        vm.label(RELAYER, "RELAYER");
        vm.label(AUDITOR, "AUDITOR");
    }

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    // Common events that multiple contracts emit
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
}
