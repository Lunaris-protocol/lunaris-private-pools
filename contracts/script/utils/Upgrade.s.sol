// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";

import {UUPSUpgradeable} from "@oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ICreateX} from "../../src/interfaces/external/ICreateX.sol";
import {DeployLib} from "libraries/DeployLib.sol";
import {Entrypoint} from "../../src/contracts/Entrypoint.sol";

/**
 * @title Upgrade
 * @notice Script to upgrade the Entrypoint implementation
 * @dev Uses UUPS upgrade pattern
 */
contract Upgrade is Script {
    using stdJson for string;

    address public entrypointProxy;
    address public deployer;
    address public owner;

    ICreateX public constant CreateX =
        ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    error EntrypointNotFound();

    function setUp() public virtual {
        deployer = vm.envAddress("DEPLOYER_ADDRESS");
        owner = vm.envAddress("OWNER_ADDRESS");

        // Load current entrypoint address
        _loadEntrypointAddress();
    }

    /**
     * @notice Upgrades the Entrypoint implementation
     * @dev Deploys new implementation and calls upgradeToAndCall
     */
    function upgradeEntrypoint() public {
        vm.startBroadcast(owner);

        // Deploy new implementation
        address newImpl = CreateX.deployCreate2(
            DeployLib.salt(deployer, DeployLib.ENTRYPOINT_IMPL_V2_SALT),
            type(Entrypoint).creationCode
        );

        console.log("New Entrypoint implementation deployed at:", newImpl);

        // Upgrade the proxy to the new implementation
        UUPSUpgradeable(entrypointProxy).upgradeToAndCall(newImpl, "");

        console.log("Entrypoint proxy upgraded to new implementation");

        // Save upgrade info
        _saveUpgradeData(newImpl);

        vm.stopBroadcast();
    }

    /**
     * @notice Upgrades the Entrypoint implementation with initialization call
     * @param initData Initialization data to call after upgrade
     */
    function upgradeEntrypointWithInit(bytes memory initData) public {
        vm.startBroadcast(owner);

        // Deploy new implementation
        address newImpl = CreateX.deployCreate2(
            DeployLib.salt(deployer, DeployLib.ENTRYPOINT_IMPL_V2_SALT),
            type(Entrypoint).creationCode
        );

        console.log("New Entrypoint implementation deployed at:", newImpl);

        // Upgrade the proxy to the new implementation with initialization
        UUPSUpgradeable(entrypointProxy).upgradeToAndCall(newImpl, initData);

        console.log("Entrypoint proxy upgraded with initialization");

        // Save upgrade info
        _saveUpgradeData(newImpl);

        vm.stopBroadcast();
    }

    /**
     * @notice Gets the current implementation address of the proxy
     * @return impl The current implementation address
     */
    function getCurrentImplementation() public view returns (address impl) {
        // Storage slot for implementation in ERC1967
        bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        assembly {
            impl := sload(slot)
        }
    }

    function _loadEntrypointAddress() private {
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
            entrypointProxy = vm.parseAddress(entrypointAddr);

            console.log("Loaded Entrypoint proxy address:", entrypointProxy);
            console.log("Current implementation:", getCurrentImplementation());
        } catch {
            revert EntrypointNotFound();
        }
    }

    function _saveUpgradeData(address newImpl) private {
        // Create upgrade record
        string memory upgradeData = string.concat(
            '{"chainId":',
            vm.toString(block.chainid),
            ',"timestamp":',
            vm.toString(block.timestamp),
            ',"block":',
            vm.toString(block.number),
            ',"proxyAddress":"',
            _addressToString(entrypointProxy),
            '","newImplementation":"',
            _addressToString(newImpl),
            '","upgrader":"',
            _addressToString(owner),
            '"}'
        );

        // Save to upgrades directory
        string memory fileName = string.concat(
            "upgrades/",
            vm.toString(block.chainid),
            "_",
            vm.toString(block.timestamp),
            ".json"
        );

        vm.writeFile(fileName, upgradeData);
        console.log("Upgrade data saved to:", fileName);
    }

    function _addressToString(
        address addr
    ) internal pure returns (string memory) {
        return vm.toString(addr);
    }
}
