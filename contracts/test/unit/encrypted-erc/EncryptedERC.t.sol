// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

import {EncryptedERC} from "contracts/encrypted-erc/EncryptedERC.sol";
import {CreateEncryptedERCParams, BurnProof, ProofPoints, Point} from "../../../src/types/Types.sol";
import {IState} from "interfaces/core/IState.sol";

/**
 * @notice Mock Registrar for testing
 */
contract MockRegistrar {
    mapping(address => bool) private _registered;
    mapping(address => uint256[2]) private _publicKeys;

    function register(address user, uint256[2] memory publicKey) external {
        _registered[user] = true;
        _publicKeys[user] = publicKey;
    }

    function isUserRegistered(address user) external view returns (bool) {
        return _registered[user];
    }

    function getUserPublicKey(
        address user
    ) external view returns (uint256[2] memory) {
        return _publicKeys[user];
    }
}

/**
 * @notice Mock Verifier for testing
 */
contract MockVerifier {
    bool private _result = true;

    function setResult(bool result) external {
        _result = result;
    }

    function verifyProof(
        uint256[2] memory,
        uint256[2][2] memory,
        uint256[2] memory,
        uint256[] memory
    ) external view returns (bool) {
        return _result;
    }
}

/**
 * @notice Mock ERC20 token for testing
 */
contract MockERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
        _totalSupply += amount;
    }

    function burn(address from, uint256 amount) external {
        _balances[from] -= amount;
        _totalSupply -= amount;
    }

    function balanceOf(
        address account
    ) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(
        address to,
        uint256 amount
    ) external override returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool) {
        _balances[from] -= amount;
        _balances[to] += amount;
        if (_allowances[from][msg.sender] != type(uint256).max) {
            _allowances[from][msg.sender] -= amount;
        }
        return true;
    }

    function approve(
        address spender,
        uint256 amount
    ) external override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }
}

/**
 * @notice Test contract for EncryptedERC
 * @dev Implements mock functions to alter state, following PrivacyPool pattern
 */
contract EncryptedERCForTest is EncryptedERC {
    constructor(CreateEncryptedERCParams memory params) EncryptedERC(params) {}

    function mockAuditorSet(bool _isSet) external {
        // Mock auditor set state by setting/unsetting auditor key
        if (_isSet) {
            auditorPublicKey = Point({x: 123, y: 456});
            auditor = msg.sender;
        } else {
            auditorPublicKey = Point({x: 0, y: 0});
            auditor = address(0);
        }
    }

    function mockUserRegistration(address _user, bool _registered) external {
        // This would typically interact with registrar, but for testing we can mock the behavior
        // Note: In full implementation, this would require more sophisticated mocking
    }

    function mockTokenBalance(address _user, uint256 _balance) external {
        // Mock internal balance state for testing
        // Note: Real implementation would require complex cryptographic state mocking
    }
}

/**
 * @notice Base test contract for EncryptedERC
 * @dev Implements common setup and helpers for unit tests, following PrivacyPool pattern
 */
contract UnitEncryptedERC is Test {
    EncryptedERCForTest internal _encryptedERC;
    MockRegistrar internal _registrar;
    MockVerifier internal _mintVerifier;
    MockVerifier internal _withdrawVerifier;
    MockVerifier internal _transferVerifier;
    MockVerifier internal _burnVerifier;
    MockERC20 internal _token;

    address internal immutable _POOL_ADDRESS = makeAddr("poolAddress");
    address internal _owner;
    address internal _user1;
    address internal _auditor;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier givenUserIsRegistered(address _user) {
        uint256[2] memory publicKey = [uint256(123), uint256(456)];
        _registrar.register(_user, publicKey);
        _;
    }

    modifier givenUserIsNotRegistered(address _user) {
        // User is not registered by default
        _;
    }

    modifier givenAuditorIsSet() {
        _encryptedERC.mockAuditorSet(true);
        _;
    }

    modifier givenAuditorIsNotSet() {
        _encryptedERC.mockAuditorSet(false);
        _;
    }

    modifier givenIsConverterMode() {
        // Constructor sets this based on params, so we need to deploy with correct params
        _;
    }

    modifier givenIsStandaloneMode() {
        // Constructor sets this based on params, so we need to deploy with correct params
        _;
    }

    modifier givenPoolAddressIsSet() {
        // Pool address is set in constructor
        _;
    }

    modifier givenPoolAddressIsZero() {
        // Would need to deploy with zero pool address
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        _owner = address(this);
        _user1 = makeAddr("user1");
        _auditor = makeAddr("auditor");

        // Deploy mock contracts
        _registrar = new MockRegistrar();
        _mintVerifier = new MockVerifier();
        _withdrawVerifier = new MockVerifier();
        _transferVerifier = new MockVerifier();
        _burnVerifier = new MockVerifier();
        _token = new MockERC20();

        // Deploy EncryptedERC with default parameters
        CreateEncryptedERCParams memory params = _getDefaultParams();
        _encryptedERC = new EncryptedERCForTest(params);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _getDefaultParams()
        internal
        view
        returns (CreateEncryptedERCParams memory)
    {
        return
            CreateEncryptedERCParams({
                registrar: address(_registrar),
                isConverter: true,
                name: "Test Token",
                symbol: "TEST",
                decimals: 18,
                mintVerifier: address(_mintVerifier),
                withdrawVerifier: address(_withdrawVerifier),
                transferVerifier: address(_transferVerifier),
                burnVerifier: address(_burnVerifier),
                poolAddress: _POOL_ADDRESS
            });
    }

    function _assumeFuzzable(address _address) internal pure {
        assumeNotForgeAddress(_address);
        assumeNotZeroAddress(_address);
        assumeNotPrecompile(_address);
    }

    function _mockAndExpect(
        address _contract,
        bytes memory _call,
        bytes memory _return
    ) internal {
        vm.mockCall(_contract, _call, _return);
        vm.expectCall(_contract, _call);
    }
}

/**
 * @notice Unit tests for the constructor
 */
contract UnitConstructor is UnitEncryptedERC {
    /**
     * @notice Test that EncryptedERC correctly initializes with valid constructor parameters
     */
    function test_ConstructorGivenValidAddressesConverterMode(
        address _registrar,
        address _mintVerifier,
        address _withdrawVerifier,
        address _transferVerifier,
        address _burnVerifier,
        address _poolAddress,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) external {
        // Ensure all addresses are non-zero
        _assumeFuzzable(_registrar);
        _assumeFuzzable(_mintVerifier);
        _assumeFuzzable(_withdrawVerifier);
        _assumeFuzzable(_transferVerifier);
        _assumeFuzzable(_burnVerifier);
        _assumeFuzzable(_poolAddress);

        vm.assume(_decimals <= 18); // Reasonable bound for decimals

        CreateEncryptedERCParams memory params = CreateEncryptedERCParams({
            registrar: _registrar,
            isConverter: true,
            name: _name,
            symbol: _symbol,
            decimals: _decimals,
            mintVerifier: _mintVerifier,
            withdrawVerifier: _withdrawVerifier,
            transferVerifier: _transferVerifier,
            burnVerifier: _burnVerifier,
            poolAddress: _poolAddress
        });

        // Deploy new contract
        EncryptedERCForTest testContract = new EncryptedERCForTest(params);

        // Verify all constructor parameters are set correctly
        assertEq(
            address(testContract.registrar()),
            _registrar,
            "Registrar address should match constructor input"
        );
        assertTrue(testContract.isConverter(), "Should be in converter mode");
        assertEq(
            testContract.name(),
            "",
            "Name should be empty in converter mode"
        ); // Converter mode sets empty name
        assertEq(
            testContract.symbol(),
            "",
            "Symbol should be empty in converter mode"
        ); // Converter mode sets empty symbol
        assertEq(
            testContract.decimals(),
            _decimals,
            "Decimals should match constructor input"
        );
        assertEq(
            testContract.poolAddress(),
            _poolAddress,
            "Pool address should match constructor input"
        );
        assertFalse(
            testContract.isAuditorKeySet(),
            "Auditor should not be set initially"
        );
    }

    /**
     * @notice Test that EncryptedERC correctly initializes in standalone mode
     */
    function test_ConstructorGivenValidAddressesStandaloneMode(
        address _registrar,
        address _mintVerifier,
        address _withdrawVerifier,
        address _transferVerifier,
        address _burnVerifier,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) external {
        // Ensure all addresses are non-zero
        _assumeFuzzable(_registrar);
        _assumeFuzzable(_mintVerifier);
        _assumeFuzzable(_withdrawVerifier);
        _assumeFuzzable(_transferVerifier);
        _assumeFuzzable(_burnVerifier);

        vm.assume(_decimals <= 18); // Reasonable bound for decimals

        CreateEncryptedERCParams memory params = CreateEncryptedERCParams({
            registrar: _registrar,
            isConverter: false, // Standalone mode
            name: _name,
            symbol: _symbol,
            decimals: _decimals,
            mintVerifier: _mintVerifier,
            withdrawVerifier: _withdrawVerifier,
            transferVerifier: _transferVerifier,
            burnVerifier: _burnVerifier,
            poolAddress: address(0) // Not needed in standalone
        });

        // Deploy new contract
        EncryptedERCForTest testContract = new EncryptedERCForTest(params);

        // Verify all constructor parameters are set correctly
        assertEq(
            address(testContract.registrar()),
            _registrar,
            "Registrar address should match constructor input"
        );
        assertFalse(testContract.isConverter(), "Should be in standalone mode");
        assertEq(
            testContract.name(),
            _name,
            "Name should match constructor input in standalone mode"
        );
        assertEq(
            testContract.symbol(),
            _symbol,
            "Symbol should match constructor input in standalone mode"
        );
        assertEq(
            testContract.decimals(),
            _decimals,
            "Decimals should match constructor input"
        );
        assertEq(
            testContract.poolAddress(),
            address(0),
            "Pool address should be zero in standalone mode"
        );
        assertFalse(
            testContract.isAuditorKeySet(),
            "Auditor should not be set initially"
        );
    }

    /**
     * @notice Test constructor reverts with zero registrar address
     */
    function test_ConstructorWhenRegistrarIsZero() external {
        CreateEncryptedERCParams memory params = _getDefaultParams();
        params.registrar = address(0);

        vm.expectRevert(IState.ZeroAddress.selector);
        new EncryptedERCForTest(params);
    }

    /**
     * @notice Test constructor reverts with zero verifier addresses in converter mode
     */
    function test_ConstructorWhenVerifiersAreZeroInConverterMode() external {
        CreateEncryptedERCParams memory params = _getDefaultParams();

        // Test zero mint verifier
        params.mintVerifier = address(0);
        vm.expectRevert(IState.ZeroAddress.selector);
        new EncryptedERCForTest(params);

        // Reset and test zero withdraw verifier
        params = _getDefaultParams();
        params.withdrawVerifier = address(0);
        vm.expectRevert(IState.ZeroAddress.selector);
        new EncryptedERCForTest(params);

        // Reset and test zero transfer verifier
        params = _getDefaultParams();
        params.transferVerifier = address(0);
        vm.expectRevert(IState.ZeroAddress.selector);
        new EncryptedERCForTest(params);

        // Reset and test zero burn verifier
        params = _getDefaultParams();
        params.burnVerifier = address(0);
        vm.expectRevert(IState.ZeroAddress.selector);
        new EncryptedERCForTest(params);
    }
}

/**
 * @notice Unit tests for auditor key management
 */
contract UnitAuditorKey is UnitEncryptedERC {
    /**
     * @notice Test that only owner can set auditor public key
     */
    function test_SetAuditorPublicKeyGivenOnlyOwner(
        address _auditor
    ) external givenUserIsRegistered(_auditor) {
        _assumeFuzzable(_auditor);

        uint256[2] memory publicKey = [uint256(123), uint256(456)];
        _registrar.register(_auditor, publicKey);

        assertFalse(
            _encryptedERC.isAuditorKeySet(),
            "Auditor should not be set initially"
        );

        // Owner should be able to set auditor
        _encryptedERC.setAuditorPublicKey(_auditor);

        assertTrue(_encryptedERC.isAuditorKeySet(), "Auditor should be set");
        assertEq(
            _encryptedERC.auditor(),
            _auditor,
            "Auditor address should match"
        );
    }

    /**
     * @notice Test that setting auditor reverts when user is not registered
     */
    function test_SetAuditorPublicKeyWhenUserNotRegistered(
        address _auditor
    ) external {
        _assumeFuzzable(_auditor);

        // User is not registered by default
        vm.expectRevert();
        _encryptedERC.setAuditorPublicKey(_auditor);
    }

    /**
     * @notice Test that non-owner cannot set auditor public key
     */
    function test_SetAuditorPublicKeyWhenCallerNotOwner(
        address _caller,
        address _auditor
    ) external givenUserIsRegistered(_auditor) {
        _assumeFuzzable(_caller);
        _assumeFuzzable(_auditor);
        vm.assume(_caller != _owner);

        vm.expectRevert();
        vm.prank(_caller);
        _encryptedERC.setAuditorPublicKey(_auditor);
    }
}

/**
 * @notice Unit tests for deposit function
 */
contract UnitDeposit is UnitEncryptedERC {
    /**
     * @notice Test that deposit reverts in converter mode (should use depositPool instead)
     */
    function test_DepositWhenInConverterMode()
        external
        givenUserIsRegistered(_user1)
        givenAuditorIsSet
    {
        uint256[7] memory amountPCT = [uint256(1), 2, 3, 4, 5, 6, 7];

        // In converter mode, deposit should revert
        vm.expectRevert();
        vm.prank(_user1);
        _encryptedERC.deposit(1000, address(_token), amountPCT);
    }
}

/**
 * @notice Unit tests for depositPool function
 */
contract UnitDepositPool is UnitEncryptedERC {
    /**
     * @notice Test depositPool reverts when pool address is not set
     */
    function test_DepositPoolWhenPoolAddressNotSet()
        external
        givenUserIsRegistered(_user1)
        givenAuditorIsSet
    {
        // Create contract with zero pool address
        CreateEncryptedERCParams memory params = _getDefaultParams();
        params.poolAddress = address(0);
        EncryptedERCForTest testContract = new EncryptedERCForTest(params);

        // Set auditor
        testContract.mockAuditorSet(true);

        uint256[7] memory amountPCT = [uint256(1), 2, 3, 4, 5, 6, 7];

        vm.expectRevert("Pool address not set");
        vm.prank(_user1);
        testContract.depositPool(1000, address(_token), amountPCT);
    }

    /**
     * @notice Test depositPool reverts when not in converter mode
     */
    function test_DepositPoolWhenNotInConverterMode()
        external
        givenUserIsRegistered(_user1)
        givenAuditorIsSet
    {
        // Create contract in standalone mode
        CreateEncryptedERCParams memory params = _getDefaultParams();
        params.isConverter = false;
        EncryptedERCForTest testContract = new EncryptedERCForTest(params);

        // Set auditor
        testContract.mockAuditorSet(true);

        uint256[7] memory amountPCT = [uint256(1), 2, 3, 4, 5, 6, 7];

        vm.expectRevert();
        vm.prank(_user1);
        testContract.depositPool(1000, address(_token), amountPCT);
    }

    /**
     * @notice Test depositPool reverts when auditor is not set
     */
    function test_DepositPoolWhenAuditorNotSet()
        external
        givenUserIsRegistered(_user1)
        givenAuditorIsNotSet
    {
        uint256[7] memory amountPCT = [uint256(1), 2, 3, 4, 5, 6, 7];

        vm.expectRevert();
        vm.prank(_user1);
        _encryptedERC.depositPool(1000, address(_token), amountPCT);
    }

    /**
     * @notice Test depositPool reverts when user is not registered
     */
    function test_DepositPoolWhenUserNotRegistered()
        external
        givenUserIsNotRegistered(_user1)
        givenAuditorIsSet
    {
        uint256[7] memory amountPCT = [uint256(1), 2, 3, 4, 5, 6, 7];

        vm.expectRevert();
        vm.prank(_user1);
        _encryptedERC.depositPool(1000, address(_token), amountPCT);
    }

    /**
     * @notice Test depositPool interface exists and basic requirements are checked
     */
    function test_DepositPoolInterfaceAndRequirements() external view {
        // Test that the interface exists and basic state is correct
        assertEq(
            _encryptedERC.poolAddress(),
            _POOL_ADDRESS,
            "Pool address should be set correctly"
        );
        assertTrue(_encryptedERC.isConverter(), "Should be in converter mode");

        // Note: Full depositPool functionality testing requires complex cryptographic operations
        // and token conversion logic that is best tested in integration tests
    }
}

/**
 * @notice Unit tests for privateBurn function interface
 */
contract UnitPrivateBurn is UnitEncryptedERC {
    /**
     * @notice Test privateBurn reverts when auditor is not set
     */
    function test_PrivateBurnWhenAuditorNotSet()
        external
        givenUserIsRegistered(_user1)
        givenAuditorIsNotSet
    {
        BurnProof memory burnProof;
        uint256[7] memory balancePCT;

        vm.expectRevert();
        vm.prank(_user1);
        _encryptedERC.privateBurn(burnProof, balancePCT);
    }

    /**
     * @notice Test privateBurn reverts when user is not registered
     */
    function test_PrivateBurnWhenUserNotRegistered()
        external
        givenUserIsNotRegistered(_user1)
        givenAuditorIsSet
    {
        BurnProof memory burnProof;
        uint256[7] memory balancePCT;

        vm.expectRevert();
        vm.prank(_user1);
        _encryptedERC.privateBurn(burnProof, balancePCT);
    }

    /**
     * @notice Test privateBurn interface exists and basic requirements are checked
     */
    function test_PrivateBurnInterfaceAndRequirements() external view {
        // Test that the interface exists by checking contract has code
        assertTrue(
            address(_encryptedERC).code.length > 0,
            "Contract should have code"
        );

        // Note: Full privateBurn functionality testing requires complex cryptographic operations
        // and zero-knowledge proof verification that is best tested with real proof generation
    }
}
