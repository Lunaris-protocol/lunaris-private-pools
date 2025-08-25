// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";

/**
 * @title Verify
 * @notice Script to verify deployed contracts on block explorers
 * @dev Reads deployment data from JSON files and verifies contracts
 */
contract Verify is Script {
    using stdJson for string;

    struct ContractData {
        string name;
        address contractAddress;
        string constructorArgs;
    }

    /**
     * @notice Verifies all contracts for a given chain
     * @dev Usage: forge script script/utils/Verify.s.sol:Verify --rpc-url <RPC_URL> --broadcast --verify
     */
    function run() public {
        uint256 chainId = block.chainid;
        string memory fileName = string.concat(
            "deployments/",
            vm.toString(chainId),
            ".json"
        );

        // Check if deployment file exists
        try vm.readFile(fileName) returns (string memory deploymentJson) {
            console.log("Reading deployment data from:", fileName);
            _verifyContracts(deploymentJson);
        } catch {
            console.log("Deployment file not found:", fileName);
            console.log("Please run deployment script first");
            return;
        }
    }

    function _verifyContracts(string memory deploymentJson) private {
        // Parse the JSON to get contracts array
        bytes memory contractsData = deploymentJson.parseRaw(".contracts");
        ContractData[] memory contracts = abi.decode(
            contractsData,
            (ContractData[])
        );

        console.log("Found", contracts.length, "contracts to verify");

        for (uint256 i = 0; i < contracts.length; i++) {
            ContractData memory contractData = contracts[i];

            console.log("Verifying contract:", contractData.name);
            console.log("Address:", contractData.contractAddress);

            // Verify based on contract type
            if (_stringEquals(contractData.name, "WithdrawalVerifier")) {
                _verifyVerifier(
                    contractData.contractAddress,
                    "WithdrawalVerifier"
                );
            } else if (_stringEquals(contractData.name, "CommitmentVerifier")) {
                _verifyVerifier(
                    contractData.contractAddress,
                    "CommitmentVerifier"
                );
            } else if (
                _stringContains(contractData.name, "PrivacyPoolSimple")
            ) {
                _verifyPrivacyPoolSimple(
                    contractData.contractAddress,
                    contractData.constructorArgs
                );
            } else if (
                _stringContains(contractData.name, "PrivacyPoolComplex")
            ) {
                _verifyPrivacyPoolComplex(
                    contractData.contractAddress,
                    contractData.constructorArgs
                );
            } else if (
                _stringEquals(contractData.name, "Entrypoint_Implementation")
            ) {
                _verifyEntrypointImpl(contractData.contractAddress);
            } else if (_stringEquals(contractData.name, "Entrypoint_Proxy")) {
                _verifyEntrypointProxy(
                    contractData.contractAddress,
                    contractData.constructorArgs
                );
            }
        }
    }

    function _verifyVerifier(
        address contractAddress,
        string memory contractName
    ) private {
        string[] memory cmd = new string[](7);
        cmd[0] = "forge";
        cmd[1] = "verify-contract";
        cmd[2] = vm.toString(contractAddress);
        cmd[3] = string.concat(
            "contracts/verifiers/",
            contractName,
            ".sol:",
            contractName
        );
        cmd[4] = "--chain-id";
        cmd[5] = vm.toString(block.chainid);
        cmd[6] = "--watch";

        try vm.ffi(cmd) {
            console.log(contractName, "verified successfully");
        } catch {
            console.log("Failed to verify", contractName);
        }
    }

    function _verifyPrivacyPoolSimple(
        address contractAddress,
        string memory constructorArgs
    ) private {
        string[] memory cmd = new string[](9);
        cmd[0] = "forge";
        cmd[1] = "verify-contract";
        cmd[2] = vm.toString(contractAddress);
        cmd[
            3
        ] = "contracts/implementations/PrivacyPoolSimple.sol:PrivacyPoolSimple";
        cmd[4] = "--constructor-args";
        cmd[5] = constructorArgs;
        cmd[6] = "--chain-id";
        cmd[7] = vm.toString(block.chainid);
        cmd[8] = "--watch";

        try vm.ffi(cmd) {
            console.log("PrivacyPoolSimple verified successfully");
        } catch {
            console.log("Failed to verify PrivacyPoolSimple");
        }
    }

    function _verifyPrivacyPoolComplex(
        address contractAddress,
        string memory constructorArgs
    ) private {
        string[] memory cmd = new string[](9);
        cmd[0] = "forge";
        cmd[1] = "verify-contract";
        cmd[2] = vm.toString(contractAddress);
        cmd[
            3
        ] = "contracts/implementations/PrivacyPoolComplex.sol:PrivacyPoolComplex";
        cmd[4] = "--constructor-args";
        cmd[5] = constructorArgs;
        cmd[6] = "--chain-id";
        cmd[7] = vm.toString(block.chainid);
        cmd[8] = "--watch";

        try vm.ffi(cmd) {
            console.log("PrivacyPoolComplex verified successfully");
        } catch {
            console.log("Failed to verify PrivacyPoolComplex");
        }
    }

    function _verifyEntrypointImpl(address contractAddress) private {
        string[] memory cmd = new string[](7);
        cmd[0] = "forge";
        cmd[1] = "verify-contract";
        cmd[2] = vm.toString(contractAddress);
        cmd[3] = "contracts/Entrypoint.sol:Entrypoint";
        cmd[4] = "--chain-id";
        cmd[5] = vm.toString(block.chainid);
        cmd[6] = "--watch";

        try vm.ffi(cmd) {
            console.log("Entrypoint Implementation verified successfully");
        } catch {
            console.log("Failed to verify Entrypoint Implementation");
        }
    }

    function _verifyEntrypointProxy(
        address contractAddress,
        string memory constructorArgs
    ) private {
        string[] memory cmd = new string[](9);
        cmd[0] = "forge";
        cmd[1] = "verify-contract";
        cmd[2] = vm.toString(contractAddress);
        cmd[3] = "@oz/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy";
        cmd[4] = "--constructor-args";
        cmd[5] = constructorArgs;
        cmd[6] = "--chain-id";
        cmd[7] = vm.toString(block.chainid);
        cmd[8] = "--watch";

        try vm.ffi(cmd) {
            console.log("Entrypoint Proxy verified successfully");
        } catch {
            console.log("Failed to verify Entrypoint Proxy");
        }
    }

    function _stringEquals(
        string memory a,
        string memory b
    ) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function _stringContains(
        string memory str,
        string memory substr
    ) private pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory substrBytes = bytes(substr);

        if (substrBytes.length > strBytes.length) return false;
        if (substrBytes.length == 0) return true;

        for (uint256 i = 0; i <= strBytes.length - substrBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < substrBytes.length; j++) {
                if (strBytes[i + j] != substrBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }
}
