// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {InternalLeanIMT, LeafAlreadyExists, LeanIMTData} from "lean-imt/InternalLeanIMT.sol";
import {PoseidonT4} from "poseidon/PoseidonT4.sol";

import {SimpleHybridPool} from "contracts/hybrid/SimpleHybridPool.sol";
import {EncryptedERC} from "contracts/encrypted-erc/EncryptedERC.sol";
import {CreateEncryptedERCParams, BurnProof, ProofPoints} from "../../../src/types/Types.sol";
import {ProofLib} from "libraries/ProofLib.sol";
import {IPrivacyPool} from "interfaces/core/IPrivacyPool.sol";
import {IState} from "interfaces/core/IState.sol";
import {Constants} from "test/helper/Constants.sol";

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
 * @notice Mock EncryptedERC for testing
 */
contract MockEncryptedERC {
    bool public isAuditorKeySet;
    address public poolAddress;
    bool public isConverter;

    constructor(address _poolAddress, bool _isConverter) {
        poolAddress = _poolAddress;
        isConverter = _isConverter;
    }

    function setAuditorPublicKey(address) external {
        isAuditorKeySet = true;
    }

    function depositPool(uint256, address, uint256[7] memory) external {
        require(poolAddress != address(0), "Pool address not set");
        require(isConverter, "Not in converter mode");
        require(isAuditorKeySet, "Auditor not set");
    }

    function privateBurn(BurnProof memory, uint256[7] memory) external {
        require(isAuditorKeySet, "Auditor not set");
    }
}

/**
 * @notice Test contract for SimpleHybridPool
 * @dev Implements mock functions to alter state and emit events, following PrivacyPool pattern
 */
contract SimpleHybridPoolForTest is SimpleHybridPool {
    using InternalLeanIMT for LeanIMTData;

    event Pulled(address _sender, uint256 _value);
    event Pushed(address _recipient, uint256 _value);

    LeanIMTData public merkleTreeCopy;

    constructor(
        address _entrypoint,
        address _withdrawalVerifier,
        address _ragequitVerifier,
        address _asset,
        address _encryptedERC
    )
        SimpleHybridPool(
            _entrypoint,
            _withdrawalVerifier,
            _ragequitVerifier,
            _asset,
            _encryptedERC
        )
    {}

    function _pull(address _sender, uint256 _value) internal override {
        emit Pulled(_sender, _value);
    }

    function _push(address _recipient, uint256 _value) internal override {
        emit Pushed(_recipient, _value);
    }

    function mockDead() external {
        dead = true;
    }

    function mockActive() external {
        dead = false;
    }

    function mockLeafAlreadyExists(uint256 _commitment) external {
        _merkleTree.leaves[_commitment] = 1;
    }

    function mockKnownStateRoot(uint256 _stateRoot) external {
        roots[1] = _stateRoot;
    }

    function mockDeposit(address _depositor, uint256 _label) external {
        depositors[_label] = _depositor;
    }

    function mockNullifierStatus(uint256 _nullifierHash, bool _spent) external {
        nullifierHashes[_nullifierHash] = _spent;
    }

    function insertLeafInShadowTree(
        uint256 _leaf
    ) external returns (uint256 _root) {
        _root = merkleTreeCopy._insert(_leaf);
    }

    function insertLeaf(uint256 _leaf) external returns (uint256 _root) {
        _root = _insert(_leaf);
    }

    function mockTreeDepth(uint256 _depth) external {
        _merkleTree.depth = _depth;
    }

    function mockTreeSize(uint256 _size) external {
        _merkleTree.size = _size;
    }

    function mockCurrentRoot(uint256 _root) external {
        _merkleTree.sideNodes[_merkleTree.depth] = _root;
    }

    function isKnownRoot(uint256 _root) external returns (bool) {
        return _isKnownRoot(_root);
    }

    function enableHybridForTest() external {
        hybridEnabled = true;
    }

    function disableHybridForTest() external {
        hybridEnabled = false;
    }
}

/**
 * @notice Base test contract for SimpleHybridPool
 * @dev Implements common setup and helpers for unit tests, following PrivacyPool pattern
 */
contract UnitSimpleHybridPool is Test {
    using ProofLib for ProofLib.WithdrawProof;

    SimpleHybridPoolForTest internal _pool;
    MockERC20 internal _asset;
    MockEncryptedERC internal _encryptedERC;
    uint256 internal _scope;

    address internal immutable _ENTRYPOINT = makeAddr("entrypoint");
    address internal immutable _WITHDRAWAL_VERIFIER =
        makeAddr("withdrawalVerifier");
    address internal immutable _RAGEQUIT_VERIFIER =
        makeAddr("ragequitVerifier");

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier givenCallerIsEntrypoint() {
        vm.startPrank(_ENTRYPOINT);
        _;
        vm.stopPrank();
    }

    modifier givenCallerIsProcessooor(address _processooor) {
        vm.startPrank(_processooor);
        _;
        vm.stopPrank();
    }

    modifier givenPoolIsActive() {
        _pool.mockActive();
        _;
    }

    modifier givenPoolIsDead() {
        _pool.mockDead();
        _;
    }

    modifier givenHybridIsEnabled() {
        _pool.enableHybridForTest();
        _;
    }

    modifier givenHybridIsDisabled() {
        _pool.disableHybridForTest();
        _;
    }

    modifier givenValidProof(
        IPrivacyPool.Withdrawal memory _w,
        ProofLib.WithdrawProof memory _p
    ) {
        // New commitment hash
        _p.pubSignals[0] = bound(
            _p.pubSignals[0],
            1,
            Constants.SNARK_SCALAR_FIELD - 1
        );

        // Existing nullifier hash
        _p.pubSignals[1] =
            bound(_p.pubSignals[1], 1, type(uint256).max) %
            Constants.SNARK_SCALAR_FIELD;

        // Withdrawn value
        _p.pubSignals[2] =
            bound(_p.pubSignals[2], 1, type(uint256).max) %
            Constants.SNARK_SCALAR_FIELD;

        // State root
        _p.pubSignals[3] =
            bound(_p.pubSignals[3], 1, type(uint256).max) %
            Constants.SNARK_SCALAR_FIELD;

        // State tree depth
        _p.pubSignals[4] = bound(_p.pubSignals[4], 1, 32);

        // ASP tree depth
        _p.pubSignals[6] = bound(_p.pubSignals[6], 1, 32);

        // Context
        _p.pubSignals[7] =
            uint256(keccak256(abi.encode(_w, _scope))) %
            Constants.SNARK_SCALAR_FIELD;

        _;
    }

    modifier givenKnownStateRoot(uint256 _stateRoot) {
        vm.assume(_stateRoot != 0);
        _pool.mockKnownStateRoot(_stateRoot);
        _;
    }

    modifier givenLatestASPRoot(uint256 _aspRoot) {
        vm.assume(_aspRoot != 0);
        _pool.mockCurrentRoot(_aspRoot);
        _;
    }

    modifier givenValidTreeDepths(
        uint256 _stateTreeDepth,
        uint256 _aspTreeDepth
    ) {
        vm.assume(_stateTreeDepth > 0 && _stateTreeDepth <= 32);
        vm.assume(_aspTreeDepth > 0 && _aspTreeDepth <= 32);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Deploy mock asset
        _asset = new MockERC20();

        // Deploy mock EncryptedERC
        _encryptedERC = new MockEncryptedERC(address(0), true); // Will be updated after pool deployment

        // Deploy hybrid pool
        _pool = new SimpleHybridPoolForTest(
            _ENTRYPOINT,
            _WITHDRAWAL_VERIFIER,
            _RAGEQUIT_VERIFIER,
            address(_asset),
            address(_encryptedERC)
        );

        // Update EncryptedERC with correct pool address
        _encryptedERC = new MockEncryptedERC(address(_pool), true);

        // Redeploy pool with correct EncryptedERC
        _pool = new SimpleHybridPoolForTest(
            _ENTRYPOINT,
            _WITHDRAWAL_VERIFIER,
            _RAGEQUIT_VERIFIER,
            address(_asset),
            address(_encryptedERC)
        );

        // Calculate scope
        _scope =
            uint256(
                keccak256(
                    abi.encodePacked(
                        address(_pool),
                        block.chainid,
                        address(_asset)
                    )
                )
            ) %
            Constants.SNARK_SCALAR_FIELD;

        // Setup EncryptedERC auditor
        _encryptedERC.setAuditorPublicKey(makeAddr("auditor"));
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

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
contract UnitConstructor is UnitSimpleHybridPool {
    /**
     * @notice Test that the pool correctly initializes with valid constructor parameters
     */
    function test_ConstructorGivenValidAddresses(
        address _entrypoint,
        address _withdrawalVerifier,
        address _ragequitVerifier,
        address _asset,
        address _encryptedERC
    ) external {
        // Ensure all addresses are non-zero
        _assumeFuzzable(_entrypoint);
        _assumeFuzzable(_withdrawalVerifier);
        _assumeFuzzable(_ragequitVerifier);
        _assumeFuzzable(_asset);
        _assumeFuzzable(_encryptedERC);

        vm.assume(
            _entrypoint != address(0) &&
                _withdrawalVerifier != address(0) &&
                _ragequitVerifier != address(0) &&
                _asset != address(0) &&
                _encryptedERC != address(0)
        );

        // Deploy new pool and compute its scope
        SimpleHybridPoolForTest testPool = new SimpleHybridPoolForTest(
            _entrypoint,
            _withdrawalVerifier,
            _ragequitVerifier,
            _asset,
            _encryptedERC
        );
        uint256 testScope = uint256(
            keccak256(
                abi.encodePacked(address(testPool), block.chainid, _asset)
            )
        ) % Constants.SNARK_SCALAR_FIELD;

        // Verify all constructor parameters are set correctly
        assertEq(
            address(testPool.ENTRYPOINT()),
            _entrypoint,
            "Entrypoint address should match constructor input"
        );
        assertEq(
            address(testPool.WITHDRAWAL_VERIFIER()),
            _withdrawalVerifier,
            "Withdrawal verifier address should match constructor input"
        );
        assertEq(
            address(testPool.RAGEQUIT_VERIFIER()),
            _ragequitVerifier,
            "Ragequit verifier address should match constructor input"
        );
        assertEq(
            testPool.ASSET(),
            _asset,
            "Asset address should match constructor input"
        );
        assertEq(
            address(testPool.encryptedERC()),
            _encryptedERC,
            "EncryptedERC address should match constructor input"
        );
        assertEq(
            testPool.SCOPE(),
            testScope,
            "Scope should be computed correctly"
        );
        assertFalse(testPool.hybridEnabled(), "Hybrid should start disabled");
    }

    /**
     * @notice Test for the constructor when any address is zero
     */
    function test_ConstructorWhenAnyAddressIsZero() external {
        address validAddress = makeAddr("validAddress");

        vm.expectRevert(IState.ZeroAddress.selector);
        new SimpleHybridPoolForTest(
            address(0),
            validAddress,
            validAddress,
            validAddress,
            validAddress
        );
        vm.expectRevert(IState.ZeroAddress.selector);
        new SimpleHybridPoolForTest(
            validAddress,
            address(0),
            validAddress,
            validAddress,
            validAddress
        );
        vm.expectRevert(IState.ZeroAddress.selector);
        new SimpleHybridPoolForTest(
            validAddress,
            validAddress,
            address(0),
            validAddress,
            validAddress
        );
        vm.expectRevert(IState.ZeroAddress.selector);
        new SimpleHybridPoolForTest(
            validAddress,
            validAddress,
            validAddress,
            address(0),
            validAddress
        );
        vm.expectRevert(IState.ZeroAddress.selector);
        new SimpleHybridPoolForTest(
            validAddress,
            validAddress,
            validAddress,
            validAddress,
            address(0)
        );
    }
}

/**
 * @notice Unit tests for the hybridDeposit function
 */
contract UnitHybridDeposit is UnitSimpleHybridPool {
    /**
     * @notice Test that hybrid deposit correctly processes when hybrid is enabled
     */
    function test_HybridDepositWhenHybridEnabledValidParameters(
        address _depositor,
        uint256 _amount,
        uint256 _precommitmentHash
    ) external givenCallerIsEntrypoint givenPoolIsActive givenHybridIsEnabled {
        // Setup test with valid parameters
        _assumeFuzzable(_depositor);
        vm.assume(_depositor != address(0));
        vm.assume(_precommitmentHash != 0);
        vm.assume(_amount > 0);
        _amount = _bound(_amount, 1, type(uint128).max - 1);

        // Setup asset for transfers
        _asset.mint(_ENTRYPOINT, _amount);

        // Calculate expected values for deposit
        uint256 _nonce = _pool.nonce();
        uint256 _label = uint256(
            keccak256(abi.encodePacked(_scope, _nonce + 1))
        ) % Constants.SNARK_SCALAR_FIELD;
        uint256 _commitment = PoseidonT4.hash(
            [_amount, _label, _precommitmentHash]
        );
        uint256 _newRoot = _pool.insertLeafInShadowTree(_commitment);

        uint256[7] memory _amountPCT = [uint256(1), 2, 3, 4, 5, 6, 7];

        // Expect pull and hybrid deposit events
        vm.expectEmit(address(_pool));
        emit SimpleHybridPoolForTest.Pulled(_ENTRYPOINT, _amount);
        vm.expectEmit(address(_pool));
        emit SimpleHybridPool.HybridDeposit(_depositor, _commitment, _amount);

        // Execute hybrid deposit
        uint256 resultCommitment = _pool.hybridDeposit(
            _depositor,
            _amount,
            _precommitmentHash,
            _amountPCT
        );

        // Verify deposit was recorded correctly
        address _retrievedDepositor = _pool.depositors(_label);
        assertEq(
            _retrievedDepositor,
            _depositor,
            "Depositor should be recorded"
        );
        assertEq(_pool.nonce(), _nonce + 1, "Nonce should increment");
        assertEq(
            resultCommitment,
            _commitment,
            "Should return correct commitment"
        );
    }

    /**
     * @notice Test that hybrid deposit works normally when hybrid is disabled
     */
    function test_HybridDepositWhenHybridDisabledValidParameters(
        address _depositor,
        uint256 _amount,
        uint256 _precommitmentHash
    ) external givenCallerIsEntrypoint givenPoolIsActive givenHybridIsDisabled {
        // Setup test with valid parameters
        _assumeFuzzable(_depositor);
        vm.assume(_depositor != address(0));
        vm.assume(_precommitmentHash != 0);
        vm.assume(_amount > 0);
        _amount = _bound(_amount, 1, type(uint128).max - 1);

        // Setup asset for transfers
        _asset.mint(_ENTRYPOINT, _amount);

        // Calculate expected values for deposit
        uint256 _nonce = _pool.nonce();
        uint256 _label = uint256(
            keccak256(abi.encodePacked(_scope, _nonce + 1))
        ) % Constants.SNARK_SCALAR_FIELD;
        uint256 _commitment = PoseidonT4.hash(
            [_amount, _label, _precommitmentHash]
        );

        uint256[7] memory _amountPCT = [uint256(1), 2, 3, 4, 5, 6, 7];

        // Should only expect pull event, no hybrid deposit event
        vm.expectEmit(address(_pool));
        emit SimpleHybridPoolForTest.Pulled(_ENTRYPOINT, _amount);

        // Execute hybrid deposit - should work as normal deposit
        uint256 resultCommitment = _pool.hybridDeposit(
            _depositor,
            _amount,
            _precommitmentHash,
            _amountPCT
        );

        // Verify deposit was recorded correctly (but no hybrid functionality)
        address _retrievedDepositor = _pool.depositors(_label);
        assertEq(
            _retrievedDepositor,
            _depositor,
            "Depositor should be recorded"
        );
        assertEq(_pool.nonce(), _nonce + 1, "Nonce should increment");
        assertEq(
            resultCommitment,
            _commitment,
            "Should return correct commitment"
        );
    }

    /**
     * @notice Test that hybrid deposit reverts when called by non-entrypoint
     */
    function test_HybridDepositWhenCallerNotEntrypoint(
        address _caller,
        address _depositor,
        uint256 _amount,
        uint256 _precommitmentHash
    ) external {
        _assumeFuzzable(_caller);
        vm.assume(_caller != _ENTRYPOINT);
        vm.assume(_caller != address(0));

        uint256[7] memory _amountPCT = [uint256(1), 2, 3, 4, 5, 6, 7];

        vm.expectRevert();
        vm.prank(_caller);
        _pool.hybridDeposit(
            _depositor,
            _amount,
            _precommitmentHash,
            _amountPCT
        );
    }

    /**
     * @notice Test that hybrid deposit reverts when pool is dead
     */
    function test_HybridDepositWhenPoolIsDead(
        address _depositor,
        uint256 _amount,
        uint256 _precommitmentHash
    ) external givenCallerIsEntrypoint givenPoolIsDead {
        uint256[7] memory _amountPCT = [uint256(1), 2, 3, 4, 5, 6, 7];

        vm.expectRevert(IState.PoolIsDead.selector);
        _pool.hybridDeposit(
            _depositor,
            _amount,
            _precommitmentHash,
            _amountPCT
        );
    }
}

/**
 * @notice Unit tests for the hybridWithdraw function
 */
contract UnitHybridWithdraw is UnitSimpleHybridPool {
    /**
     * @notice Test that hybrid withdraw correctly processes with valid proofs
     */
    function test_HybridWithdrawWhenValidProofs(
        IPrivacyPool.Withdrawal memory _w,
        ProofLib.WithdrawProof memory _p
    )
        external
        givenCallerIsProcessooor(_w.processooor)
        givenValidProof(_w, _p)
        givenKnownStateRoot(_p.pubSignals[3])
        givenLatestASPRoot(_p.pubSignals[5])
        givenValidTreeDepths(_p.pubSignals[4], _p.pubSignals[6])
    {
        uint256 _withdrawnAmount = _p.pubSignals[2];
        _assumeFuzzable(_w.processooor);

        // Setup pool with funds
        _asset.mint(address(_pool), _withdrawnAmount);

        // Mock withdrawal verifier success
        _mockAndExpect(
            _WITHDRAWAL_VERIFIER,
            abi.encodeWithSignature(
                "verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[8])",
                _p.pA,
                _p.pB,
                _p.pC,
                _p.pubSignals
            ),
            abi.encode(true)
        );

        // Create valid burn proof and balance PCT
        BurnProof memory _burnProof = BurnProof({
            proofPoints: ProofPoints({
                a: [uint256(1), uint256(2)],
                b: [[uint256(3), uint256(4)], [uint256(5), uint256(6)]],
                c: [uint256(7), uint256(8)]
            }),
            publicSignals: [
                uint256(1),
                uint256(2),
                uint256(3),
                uint256(4),
                uint256(5),
                uint256(6),
                uint256(7),
                uint256(8),
                uint256(9),
                uint256(10),
                uint256(11),
                uint256(12),
                uint256(13),
                uint256(14),
                uint256(15),
                uint256(16),
                uint256(17),
                uint256(18),
                uint256(19)
            ]
        });

        uint256[7] memory _balancePCT = [uint256(1), 2, 3, 4, 5, 6, 7];

        // Mock the privateBurn call to succeed
        vm.mockCall(
            address(_encryptedERC),
            abi.encodeWithSignature(
                "privateBurn((uint256[2],uint256[2][2],uint256[2],uint256[19]),uint256[7])"
            ),
            abi.encode("")
        );

        // Expect withdrawal events (Withdrawn first, then HybridWithdraw)
        vm.expectEmit(address(_pool));
        emit SimpleHybridPoolForTest.Pushed(_w.processooor, _withdrawnAmount);

        // Execute hybrid withdraw
        _pool.hybridWithdraw(_w, _p, _burnProof, _balancePCT);

        // Verify nullifier was spent
        assertTrue(
            _pool.nullifierHashes(_p.pubSignals[1]),
            "Nullifier should be spent"
        );
    }

    /**
     * @notice Test that hybrid withdraw reverts when EncryptedERC burn fails
     */
    function test_HybridWithdrawWhenEncryptedERCBurnFails(
        IPrivacyPool.Withdrawal memory _w,
        ProofLib.WithdrawProof memory _p
    )
        external
        givenCallerIsProcessooor(_w.processooor)
        givenValidProof(_w, _p)
        givenKnownStateRoot(_p.pubSignals[3])
        givenLatestASPRoot(_p.pubSignals[5])
        givenValidTreeDepths(_p.pubSignals[4], _p.pubSignals[6])
    {
        uint256 _withdrawnAmount = _p.pubSignals[2];
        _assumeFuzzable(_w.processooor);

        // Setup pool with funds
        _asset.mint(address(_pool), _withdrawnAmount);

        // Mock withdrawal verifier success
        _mockAndExpect(
            _WITHDRAWAL_VERIFIER,
            abi.encodeWithSignature(
                "verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[8])",
                _p.pA,
                _p.pB,
                _p.pC,
                _p.pubSignals
            ),
            abi.encode(true)
        );

        // Create dummy burn proof
        BurnProof memory _burnProof;
        uint256[7] memory _balancePCT;

        // Mock the privateBurn call to revert
        vm.mockCallRevert(
            address(_encryptedERC),
            abi.encodeWithSignature(
                "privateBurn((uint256[2],uint256[2][2],uint256[2],uint256[19]),uint256[7])"
            ),
            "Burn failed"
        );

        // Should revert with "EncryptedERC burn failed"
        vm.expectRevert("EncryptedERC burn failed");
        _pool.hybridWithdraw(_w, _p, _burnProof, _balancePCT);
    }

    /**
     * @notice Test that hybrid withdraw reverts with invalid withdrawal proof
     */
    function test_HybridWithdrawWhenInvalidWithdrawalProof(
        IPrivacyPool.Withdrawal memory _w,
        ProofLib.WithdrawProof memory _p
    )
        external
        givenCallerIsProcessooor(_w.processooor)
        givenValidProof(_w, _p)
        givenKnownStateRoot(_p.pubSignals[3])
        givenLatestASPRoot(_p.pubSignals[5])
        givenValidTreeDepths(_p.pubSignals[4], _p.pubSignals[6])
    {
        // Mock withdrawal verifier failure
        vm.mockCall(
            _WITHDRAWAL_VERIFIER,
            abi.encodeWithSignature(
                "verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[8])",
                _p.pA,
                _p.pB,
                _p.pC,
                _p.pubSignals
            ),
            abi.encode(false)
        );

        BurnProof memory _burnProof;
        uint256[7] memory _balancePCT;

        vm.expectRevert();
        _pool.hybridWithdraw(_w, _p, _burnProof, _balancePCT);
    }
}

/**
 * @notice Unit tests for hybrid mode functionality
 */
contract UnitHybridMode is UnitSimpleHybridPool {
    /**
     * @notice Test that hybrid mode starts disabled by default
     */
    function test_HybridModeDefaultState() external view {
        assertFalse(_pool.hybridEnabled(), "Hybrid should start disabled");
    }

    /**
     * @notice Test enabling hybrid mode
     */
    function test_EnableHybridMode() external {
        assertFalse(_pool.hybridEnabled(), "Should start disabled");

        _pool.enableHybridForTest();

        assertTrue(_pool.hybridEnabled(), "Should be enabled");
    }

    /**
     * @notice Test disabling hybrid mode
     */
    function test_DisableHybridMode() external {
        _pool.enableHybridForTest();
        assertTrue(_pool.hybridEnabled(), "Should be enabled first");

        _pool.disableHybridForTest();

        assertFalse(_pool.hybridEnabled(), "Should be disabled");
    }
}
