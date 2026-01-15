// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Interface for Access Control Module
/// @notice Defines authorization, whitelist, and freeze functionalities
interface IDAO {
    
   struct Poll {
        string question;         // Intitulé du sondage
        uint256 startTime;       // Timestamp de début
        uint256 endTime;         // Timestamp de fin
        bool exists;             // Pour valider qu'un pollId est valide
    }

     function createPoll(
        string calldata question,
        string[] calldata options,
        uint256 duration
    ) external;
    
     function vote(uint256 pollId, uint256 optionIndex) external;

    function getResults(uint256 pollId) external view returns (string[] memory options, uint256[] memory results);

     function hasVotedf(uint256 pollId, address voter) external view returns (bool);

     function getVoteChoice(uint256 pollId, address voter) external view returns (uint256);

     function getVoteWeight(uint256 pollId, address voter) external view returns (uint256);
}
