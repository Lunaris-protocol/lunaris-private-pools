// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@oz/token/ERC20/ERC20.sol";

import {Entrypoint} from "../../src/contracts/Entrypoint.sol";
import {PrivacyPoolComplex} from "../../src/contracts/implementations/PrivacyPoolComplex.sol";
import {IPrivacyPool} from "../../src/interfaces/core/IPrivacyPool.sol";
import {ICreateX} from "../../src/interfaces/external/ICreateX.sol";
import {DeployLib} from "libraries/DeployLib.sol";

/**
 * @title ManagePools
 * @notice Script to manage Privacy Pools after deployment
 * @dev Can add new pools, remove existing pools, and update pool configurations
 */
contract ManagePools is Script {
    using stdJson for string;

    struct PoolConfig {
        string symbol;
        IERC20 asset;
        uint256 minimumDepositAmount;
        uint256 vettingFeeBPS;
        uint256 maxRelayFeeBPS;
    }

    Entrypoint public entrypoint;
    address public withdrawalVerifier;
    address public ragequitVerifier;
    address public deployer;
    address public owner;

    ICreateX public constant CreateX =
        ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    error EntrypointNotFound();
    error VerifiersNotFound();

    function setUp() public virtual {
        deployer = vm.envAddress("DEPLOYER_ADDRESS");
        owner = vm.envAddress("OWNER_ADDRESS");

        // Load deployment data
        _loadDeploymentData();
    }

    /**
     * @notice Adds a new ERC20 pool to the protocol
     * @dev Usage: Set pool config in this function and run the script
     */
    function addPool() public {
        vm.startBroadcast(owner);

        // Example pool configuration - modify as needed
        PoolConfig memory poolConfig = PoolConfig({
            symbol: "USDC",
            asset: IERC20(0xa0b86a33e6441041A0b10e9d6f6C3C3e6f7C7B7C), // Replace with actual USDC address
            minimumDepositAmount: 10e6, // 10 USDC (6 decimals)
            vettingFeeBPS: 50, // 0.5%
            maxRelayFeeBPS: 100 // 1%
        });

        address poolAddress = _deployComplexPool(poolConfig);
        console.log(
            "New pool deployed and registered:",
            poolConfig.symbol,
            "at",
            poolAddress
        );

        vm.stopBroadcast();
    }

    /**
     * @notice Removes an existing pool from the protocol
     * @param asset The asset of the pool to remove
     */
    function removePool(IERC20 asset) public {
        vm.startBroadcast(owner);

        entrypoint.removePool(asset);
        console.log("Pool removed for asset:", address(asset));

        vm.stopBroadcast();
    }

    /**
     * @notice Updates the configuration of an existing pool
     * @param asset The asset of the pool to update
     * @param minimumDepositAmount New minimum deposit amount
     * @param vettingFeeBPS New vetting fee in basis points
     * @param maxRelayFeeBPS New maximum relay fee in basis points
     */
    function updatePoolConfiguration(
        IERC20 asset,
        uint256 minimumDepositAmount,
        uint256 vettingFeeBPS,
        uint256 maxRelayFeeBPS
    ) public {
        vm.startBroadcast(owner);

        entrypoint.updatePoolConfiguration(
            asset,
            minimumDepositAmount,
            vettingFeeBPS,
            maxRelayFeeBPS
        );
        console.log("Pool configuration updated for asset:", address(asset));

        vm.stopBroadcast();
    }

    /**
     * @notice Winds down a pool (irreversibly disables deposits)
     * @param pool The pool contract to wind down
     */
    function windDownPool(IPrivacyPool pool) public {
        vm.startBroadcast(owner);

        entrypoint.windDownPool(pool);
        console.log("Pool wound down:", address(pool));

        vm.stopBroadcast();
    }

    /**
     * @notice Withdraws accumulated fees for a specific asset
     * @param asset The asset to withdraw fees for
     * @param recipient The address to receive the fees
     */
    function withdrawFees(IERC20 asset, address recipient) public {
        vm.startBroadcast(owner);

        entrypoint.withdrawFees(asset, recipient);
        console.log(
            "Fees withdrawn for asset:",
            address(asset),
            "to:",
            recipient
        );

        vm.stopBroadcast();
    }

    function _deployComplexPool(
        PoolConfig memory _config
    ) private returns (address) {
        // Encode constructor args
        bytes memory constructorArgs = abi.encode(
            address(entrypoint),
            withdrawalVerifier,
            ragequitVerifier,
            address(_config.asset)
        );

        // Deploy pool with Create2
        bytes11 _tokenSalt = bytes11(
            keccak256(
                abi.encodePacked(DeployLib.COMPLEX_POOL_SALT, _config.symbol)
            )
        );

        address _pool = CreateX.deployCreate2(
            DeployLib.salt(deployer, _tokenSalt),
            abi.encodePacked(
                type(PrivacyPoolComplex).creationCode,
                constructorArgs
            )
        );

        // Register pool at entrypoint with defined configuration
        entrypoint.registerPool(
            _config.asset,
            IPrivacyPool(_pool),
            _config.minimumDepositAmount,
            _config.vettingFeeBPS,
            _config.maxRelayFeeBPS
        );

        return _pool;
    }

    function _loadDeploymentData() private {
        uint256 chainId = block.chainid;
        string memory fileName = string.concat(
            "deployments/",
            vm.toString(chainId),
            ".json"
        );

        try vm.readFile(fileName) returns (string memory deploymentJson) {
            // Find Entrypoint proxy
            string
                memory entrypointQuery = ".contracts[?(@.name == 'Entrypoint_Proxy')].address";
            string memory entrypointAddr = deploymentJson.readString(
                entrypointQuery
            );

            if (bytes(entrypointAddr).length == 0) revert EntrypointNotFound();
            entrypoint = Entrypoint(payable(vm.parseAddress(entrypointAddr)));

            // Find verifiers
            string
                memory withdrawalVerifierQuery = ".contracts[?(@.name == 'WithdrawalVerifier')].address";
            string memory withdrawalAddr = deploymentJson.readString(
                withdrawalVerifierQuery
            );

            string
                memory ragequitVerifierQuery = ".contracts[?(@.name == 'CommitmentVerifier')].address";
            string memory ragequitAddr = deploymentJson.readString(
                ragequitVerifierQuery
            );

            if (
                bytes(withdrawalAddr).length == 0 ||
                bytes(ragequitAddr).length == 0
            ) {
                revert VerifiersNotFound();
            }

            withdrawalVerifier = vm.parseAddress(withdrawalAddr);
            ragequitVerifier = vm.parseAddress(ragequitAddr);
        } catch {
            revert EntrypointNotFound();
        }
    }
}
