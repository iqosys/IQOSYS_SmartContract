// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "./IHashRegistry.sol";

/// @title Hash Registry Module
/// @notice Stores and verifies valid hashes
contract HashRegistry is Ownable, IHashRegistry, ERC2771Context {


    constructor(address initialOwner, address forwarder) 
        Ownable(msg.sender) 
        ERC2771Context(forwarder) 
    {

        _transferOwnership(initialOwner);
    }

    mapping(bytes32 => bool) private validHashes;

    event HashAdded(bytes32 indexed hash);
    event HashRemoved(bytes32 indexed hash);


    function addValidHash(bytes32 hash) external onlyOwner {
        require(!validHashes[hash], "Hash already added");
        validHashes[hash] = true;
        emit HashAdded(hash);
    }

    function removeValidHash(bytes32 hash) external onlyOwner {
        require(validHashes[hash], "Hash not found");
        validHashes[hash] = false;
        emit HashRemoved(hash); 
    }

    function isHashValid(bytes32 hash) external view returns (bool) {
        return validHashes[hash];
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