// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "./IAccessControl.sol";

/// @title Access Control Module
/// @notice Manages owner, authorized addresses, whitelist and frozen accounts
contract AccessControl is Ownable, IAccessControl, ERC2771Context {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private iqosysWhiteList;
    mapping(address => bool) private authorizedAddresses;
    mapping(address => bool) private frozenAddresses;

    event AuthorizationUpdated(address indexed account, bool isAuthorized);
    event WhiteListed(address indexed account, bool status);
    event AddressFrozen(address indexed account, bool isFrozen);

    /**
     * @notice Initialise le module avec le propriétaire et le relais de gas
     * @param initialOwner L'adresse de l'administrateur
     * @param forwarder L'adresse du contrat MinimalForwarder
     */
    constructor(address initialOwner, address forwarder) 
        Ownable(msg.sender) 
        ERC2771Context(forwarder) 
    {
        _transferOwnership(initialOwner);
        authorizedAddresses[initialOwner] = true;
        iqosysWhiteList.add(initialOwner);
    }

    // --- RÉSOLUTION DES CONFLITS D'HÉRITAGE (CONTEXT) ---

    function _msgSender() internal view override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    function _contextSuffixLength() internal view override(Context, ERC2771Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }

    // --- LOGIQUE MÉTIER ---

    function owner() public view override(Ownable, IAccessControl) returns (address) {
        return Ownable.owner();
    }

    function authorizeAddress(address account) external onlyOwner override {
        require(!authorizedAddresses[account], "Address already authorized");
        authorizedAddresses[account] = true;
        emit AuthorizationUpdated(account, true);
    }

    function revokeAuthorization(address account) external onlyOwner override {
        require(authorizedAddresses[account], "Address not authorized");
        authorizedAddresses[account] = false;
        emit AuthorizationUpdated(account, false);
    }

    function addToWhiteList(address account) external onlyOwner override {
        require(iqosysWhiteList.add(account), "Account already white-listed");
        emit WhiteListed(account, true);
    }

    function removeFromWhiteList(address account) external onlyOwner override {
        require(iqosysWhiteList.remove(account), "Account not in white-list");
        emit WhiteListed(account, false);
    }

    function freezeAddress(address account) external onlyOwner override {
        require(!frozenAddresses[account], "Address already frozen");
        frozenAddresses[account] = true;
        emit AddressFrozen(account, true);
    }

    function unfreezeAddress(address account) external onlyOwner override {
        require(frozenAddresses[account], "Address not frozen");
        frozenAddresses[account] = false;
        emit AddressFrozen(account, false);
    }

    function isAuthorized(address account) external view override returns (bool) {
        return authorizedAddresses[account];
    }

    function isWhiteListed(address account) external view override returns (bool) {
        return iqosysWhiteList.contains(account);
    }

    function isFrozen(address account) external view override returns (bool) {
          return frozenAddresses[account];
    }

    function onlyValidSender(address account) external view override returns (bool) {
        require(this.isWhiteListed(account), "Sender not white-listed");
        require(this.isAuthorized(account), "Sender not authorized");
        require(!this.isFrozen(account), "Sender is frozen");
        return true;
    }

    function getWhiteList() public view returns (address[] memory) {
        return iqosysWhiteList.values();
    }
}