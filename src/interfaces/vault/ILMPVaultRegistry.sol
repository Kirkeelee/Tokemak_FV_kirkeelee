//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISystemBound } from "src/interfaces/ISystemBound.sol";

/// @title Keep track of Vaults created through the Vault Factory
interface ILMPVaultRegistry is ISystemBound {
    ///////////////////////////////////////////////////////////////////
    //                        Errors
    ///////////////////////////////////////////////////////////////////

    error VaultNotFound(address vaultAddress);
    error VaultAlreadyExists(address vaultAddress);

    ///////////////////////////////////////////////////////////////////
    //                        Events
    ///////////////////////////////////////////////////////////////////
    event VaultAdded(address indexed asset, address indexed vault);
    event VaultRemoved(address indexed asset, address indexed vault);

    ///////////////////////////////////////////////////////////////////
    //                        Functions
    ///////////////////////////////////////////////////////////////////

    /// @notice Checks if an address is a valid vault
    /// @param vaultAddress Vault address to be added
    function isVault(address vaultAddress) external view returns (bool);

    /// @notice Registers a vault
    /// @param vaultAddress Vault address to be added
    function addVault(address vaultAddress) external;

    /// @notice Removes vault registration
    /// @param vaultAddress Vault address to be removed
    function removeVault(address vaultAddress) external;

    /// @notice Returns a list of all registered vaults
    function listVaults() external view returns (address[] memory);

    /// @notice Returns a list of all registered vaults for a given asset
    /// @param asset Asset address
    function listVaultsForAsset(address asset) external view returns (address[] memory);

    /// @notice Returns a list of all registered vaults for a given type
    /// @param _vaultType Vault type
    function listVaultsForType(bytes32 _vaultType) external view returns (address[] memory);
}