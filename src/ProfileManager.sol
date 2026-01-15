// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "./IProfileManager.sol";

/// @title Profile Manager Module
/// @notice Manages user profiles (CRUD)

contract ProfileManager is Ownable, IProfileManager, ERC2771Context {
    struct UserProfile {
        string email;
        string firstName;
        string lastName;
    }

    mapping(address => UserProfile) private profiles;
    event UserProfileUpdated(address indexed user, string email, string firstName, string lastName);

    /// @param initialOwner Owner of this contract
    /// @param forwarder Address of the Trusted Forwarder

    constructor(address initialOwner, address forwarder) 
        Ownable(msg.sender) 
        ERC2771Context(forwarder) 
    {
        // Transfère la propriété au véritable owner
        _transferOwnership(initialOwner);
    }

    /// @notice Sets or updates a user's profile

    function setUserProfile(
        address account,
        string calldata email,
        string calldata firstName,
        string calldata lastName
    ) external onlyOwner override {
        profiles[account] = UserProfile(email, firstName, lastName);
        emit UserProfileUpdated(account, email, firstName, lastName);
    }

    /// @notice Deletes a user's profile
    function deleteUserProfile(address account) external onlyOwner override {
        delete profiles[account];
    }

    /// @notice Retrieves a user's profile
    function getUserProfile(address account)
        external
        view
        override
        returns (
            string memory email,
            string memory firstName,
            string memory lastName
        )
    {
        UserProfile storage p = profiles[account];
        return (p.email, p.firstName, p.lastName);
    }



    function _msgSender() internal view override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    function _contextSuffixLength() internal view override(Context, ERC2771Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}