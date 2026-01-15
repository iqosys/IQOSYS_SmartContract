// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Interface for Hash Registry Module
/// @notice Manages storage and verification of valid hashes
interface IHashRegistry {
    /// @notice Adds a valid hash (owner only)
    function addValidHash(bytes32 hash) external;

    /// @notice Removes a valid hash (owner only)
    function removeValidHash(bytes32 hash) external;

    /// @notice Checks if a hash is valid
    function isHashValid(bytes32 hash) external view returns (bool);



}
