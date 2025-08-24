// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

/**
 * @title ICreateX
 * @notice Interface for the CreateX factory contract
 * @dev Used for deterministic contract deployments using CREATE2
 */
interface ICreateX {
    /**
     * @notice Deploys a contract using CREATE2
     * @param salt The salt used for CREATE2 deployment
     * @param initCode The creation code of the contract
     * @return contractAddress The address of the deployed contract
     */
    function deployCreate2(
        bytes32 salt,
        bytes memory initCode
    ) external returns (address contractAddress);
}
