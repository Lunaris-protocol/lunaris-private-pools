// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import {SimpleHybridPool} from "../src/contracts/hybrid/SimpleHybridPool.sol";
import {EncryptedERC} from "../src/contracts/encrypted-erc/EncryptedERC.sol";
import {CreateEncryptedERCParams} from "../src/types/Types.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

// Mock contracts for deployment testing
contract MockVerifier {
    function verifyProof(
        uint256[2] memory,
        uint256[2][2] memory,
        uint256[2] memory,
        uint256[] memory
    ) external pure returns (bool) {
        return true;
    }
}

contract MockRegistrar {
    mapping(address => bool) private _registered;

    function isUserRegistered(address user) external view returns (bool) {
        return _registered[user];
    }

    function register(address user) external {
        _registered[user] = true;
    }

    function getUserPublicKey(
        address
    ) external pure returns (uint256[2] memory) {
        return [uint256(123), uint256(456)];
    }
}

contract MockERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        _allowances[from][msg.sender] -= amount;
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
        _totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
}

/**
 * @title DeployHybridSystem
 * @notice Script to deploy the complete hybrid system with proper setup
 * @dev This script demonstrates the correct deployment order and configuration
 */
contract DeployHybridSystem is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("=== DEPLOYING LUNARIS HYBRID SYSTEM ===");
        console.log("Deployer:", deployer);
        console.log("Network:", block.chainid);
        console.log("");

        // 1. Deploy mock dependencies for testing
        console.log("1. Deploying mock dependencies...");
        MockRegistrar registrar = new MockRegistrar();
        MockVerifier withdrawalVerifier = new MockVerifier();
        MockVerifier ragequitVerifier = new MockVerifier();
        MockVerifier mintVerifier = new MockVerifier();
        MockVerifier transferVerifier = new MockVerifier();
        MockVerifier burnVerifier = new MockVerifier();
        MockERC20 asset = new MockERC20("Test USDC", "TUSDC");

        console.log("  Registrar:", address(registrar));
        console.log("  Asset:", address(asset));
        console.log("");

        // 2. Deploy EncryptedERC with pool address as zero initially
        console.log("2. Deploying EncryptedERC...");
        CreateEncryptedERCParams memory params = CreateEncryptedERCParams({
            registrar: address(registrar),
            isConverter: true,
            name: "Hybrid USDC",
            symbol: "hUSDC",
            decimals: 6,
            mintVerifier: address(mintVerifier),
            withdrawVerifier: address(withdrawalVerifier),
            transferVerifier: address(transferVerifier),
            burnVerifier: address(burnVerifier),
            poolAddress: address(0) // Will be updated after pool deployment
        });

        EncryptedERC encryptedERC = new EncryptedERC(params);
        console.log("  EncryptedERC deployed at:", address(encryptedERC));

        // 3. Deploy SimpleHybridPool
        console.log("3. Deploying SimpleHybridPool...");

        // For production, use real entrypoint address
        address entrypoint = vm.envOr("ENTRYPOINT_ADDRESS", deployer);

        SimpleHybridPool hybridPool = new SimpleHybridPool(
            entrypoint,
            address(withdrawalVerifier),
            address(ragequitVerifier),
            address(asset),
            address(encryptedERC)
        );
        console.log("  SimpleHybridPool deployed at:", address(hybridPool));
        console.log("");

        // 4. Configure the system
        console.log("4. Configuring hybrid system...");

        // Register deployer for testing
        registrar.register(deployer);
        console.log("Deployer registered");

        // Set auditor on EncryptedERC (using deployer for demo)
        encryptedERC.setAuditorPublicKey(deployer);
        console.log("Auditor set on EncryptedERC");

        // Mint some test tokens for demonstration
        asset.mint(deployer, 1000000 * 10 ** 6); // 1M TUSDC
        console.log(" Test tokens minted");

        console.log("");
        console.log("=== DEPLOYMENT COMPLETED SUCCESSFULLY ===");
        console.log("");
        console.log("Deployed contracts:");
        console.log("        EncryptedERC:     ", address(encryptedERC));
        console.log("        SimpleHybridPool: ", address(hybridPool));
        console.log("        Asset (ERC20):    ", address(asset));
        console.log("        Registrar:        ", address(registrar));
        console.log("        Verifiers:        All deployed");
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Enable hybrid mode: hybridPool.setHybridEnabled(true)");
        console.log("2. Register users: registrar.register(userAddress)");
        console.log("3. Test hybrid deposits and withdrawals");
        console.log("");
        console.log("TESTING COMMANDS:");
        console.log("forge test --match-contract HybridIntegration -vv");
        console.log("forge test --match-path '**/hybrid/*' -vvv");

        vm.stopBroadcast();
    }
}
