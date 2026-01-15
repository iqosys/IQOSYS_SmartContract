// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Interface for IQS ↔ OST Conversion Module
/// @notice Handles conversion requests, approvals, rejections, and history
interface IConversionModule {
    struct PendingIQSToOSTConversion {
        address requester;
        uint256 amount;
    }

    /// @notice Request conversion of IQS to OST
    function requestIQSToOSTConversion(uint256 amount) external;

    /// @notice Approve a pending conversion request (owner only)
    function approveIQSToOSTConversion(uint256 requestId) external;

    /// @notice Reject a pending conversion request (owner only)
    function rejectIQSToOSTConversion(uint256 requestId) external;

    /// @notice Cancel a pending conversion request (requester only)
    function cancelIQSToOSTConversion(uint256 requestId) external;

    /// @notice Get the history of IQS to OST conversion
    function getIQSToOSTConversionHistory() external view returns (address[] memory requesters, uint256[] memory amounts);
        
    /// @notice Get the history of IQS to OST conversion for a specific user
    function getUserIQSToOSTConversionHistory(address user) external view returns (uint256[] memory requestIds, uint256[] memory amounts);
   
   /// @notice Gets the length of the transaction history from IQS to OST
    function getTransactionHistoryLengthIQStoOST() external view returns (uint256);
}
