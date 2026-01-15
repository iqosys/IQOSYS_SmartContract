// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Interface for Profile Manager Module
/// @notice Defines CRUD operations for user profiles
interface IProfileManager {
    /// @notice Creates or updates a user's profile
    function setUserProfile(address account, string calldata email, string calldata firstName, string calldata lastName) external;

    /// @notice Deletes a user's profile
    function deleteUserProfile(address account) external;

    /// @notice Retrieves a user's profile
    function getUserProfile(address account) external view returns (string memory email, string memory firstName, string memory lastName);
}
