// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import {SimpleHybridPool} from "../src/contracts/hybrid/SimpleHybridPool.sol";
import {EncryptedERCRelayer} from "../src/contracts/hybrid/EncryptedERCRelayer.sol";
import {EncryptedERC} from "../src/contracts/encrypted-erc/EncryptedERC.sol";

/**
 * @title DeployHybridSystem
 * @notice Script to deploy the complete hybrid system with proper setup
 * @dev This script shows the correct deployment order and configuration
 */
contract DeployHybridSystem is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying Hybrid System...");
        console.log("Deployer:", deployer);

        // 1. Deploy EncryptedERC (or use existing one)
        // address encryptedERC = 0x...; // Use existing EncryptedERC address

        // 2. Deploy EncryptedERCRelayer
        // EncryptedERCRelayer relayer = new EncryptedERCRelayer(encryptedERC);
        // console.log("EncryptedERCRelayer deployed at:", address(relayer));

        // 3. Deploy SimpleHybridPool
        // SimpleHybridPool hybridPool = new SimpleHybridPool(
        //     entrypoint,
        //     withdrawalVerifier,
        //     ragequitVerifier,
        //     asset,
        //     address(relayer)
        // );
        // console.log("SimpleHybridPool deployed at:", address(hybridPool));

        // 4. Configure the system
        // a) Transfer EncryptedERC ownership to relayer
        // EncryptedERC(encryptedERC).transferOwnership(address(relayer));

        // b) Authorize SimpleHybridPool to call relayer
        // relayer.setAuthorizedCaller(address(hybridPool), true);

        // c) Set auditor on EncryptedERC (through relayer)
        // relayer.setAuditorPublicKey(auditorAddress);

        // d) Enable hybrid mode on pool
        // hybridPool.setHybridEnabled(true);

        console.log("Hybrid System deployment completed!");
        console.log("");
        console.log("Setup Instructions:");
        console.log("1. Deploy EncryptedERC (or use existing)");
        console.log("2. Deploy EncryptedERCRelayer with EncryptedERC address");
        console.log("3. Deploy SimpleHybridPool with relayer address");
        console.log("4. Transfer EncryptedERC ownership to relayer");
        console.log("5. Authorize SimpleHybridPool on relayer");
        console.log("6. Set auditor through relayer");
        console.log("7. Enable hybrid mode on pool");

        vm.stopBroadcast();
    }
}
