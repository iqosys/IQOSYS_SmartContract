// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol"; 
import "./IDAO.sol";
import "./ITokenManager.sol";


contract DAO is Ownable, IDAO, ERC2771Context {
    ITokenManager public tokenManager;

    uint256 public pollCount;
    mapping(uint256 => Poll) public polls;
    mapping(uint256 => string[]) private pollOptions;
    
    mapping(uint256 => mapping(uint256 => uint256)) public pollVotes;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => uint256)) public voteChoice;
    mapping(uint256 => mapping(address => uint256)) public voteWeight;

    event PollCreated(
        uint256 indexed pollId,
        string question,
        string[] options,
        uint256 startTime,
        uint256 endTime
    );
    event VoteCast(
        uint256 indexed pollId,
        address indexed voter,
        uint256 optionIndex,
        uint256 weight
    );

    constructor(
        address tokenManagerAddress, 
        address initialOwner, 
        address forwarder
    ) 
        Ownable(msg.sender) 
        ERC2771Context(forwarder) 
    {
        require(tokenManagerAddress != address(0), "Invalid TokenManager address");
        _transferOwnership(initialOwner);
        tokenManager = ITokenManager(tokenManagerAddress);
    }

    /// @notice Crée un nouveau sondage
    function createPoll(
        string calldata question,
        string[] calldata options,
        uint256 duration
    ) external onlyOwner { 
        
        require(options.length >= 2, "Need at least two options");
        require(duration > 0, "Duration must be > 0");

        uint256 id = pollCount;
        polls[id] = Poll({
            question: question,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            exists: true
        });
        
        for (uint256 i = 0; i < options.length; i++) {
            pollOptions[id].push(options[i]);
        }

        emit PollCreated(
            id,
            question,
            options,
            polls[id].startTime,
            polls[id].endTime
        );
        pollCount++;
    }

    /// @notice Vote sur une option d’un sondage existant
    function vote(uint256 pollId, uint256 optionIndex) external {
        address sender = _msgSender();

        Poll storage p = polls[pollId];
        require(p.exists, "Poll does not exist");
        require(block.timestamp >= p.startTime, "Poll not started");
        require(block.timestamp <= p.endTime, "Poll ended");
        require(!hasVoted[pollId][sender], "Already voted");

        uint256 weight = tokenManager.balanceOfIQS(sender);
        require(weight > 0, "Must hold >0 IQS to vote");
        require(optionIndex < pollOptions[pollId].length, "Invalid option");

        hasVoted[pollId][sender] = true;
        voteChoice[pollId][sender] = optionIndex;
        voteWeight[pollId][sender] = weight;
        pollVotes[pollId][optionIndex] += weight;

        emit VoteCast(pollId, sender, optionIndex, weight);
    }

    /// @notice Retourne les résultats pondérés d’un sondage
    function getResults(uint256 pollId)
        external
        view
        returns (string[] memory options, uint256[] memory results)
    {
        require(polls[pollId].exists, "Poll does not exist");
        uint256 len = pollOptions[pollId].length;
        options = new string[](len);
        results = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            options[i] = pollOptions[pollId][i];
            results[i] = pollVotes[pollId][i];
        }
    }

    function hasVotedf(uint256 pollId, address voter) external view returns (bool) {
        return hasVoted[pollId][voter];
    }

     function getVoteChoice(uint256 pollId, address voter) external view returns (uint256) {
        require(hasVoted[pollId][voter], "Voter has not voted");
        return voteChoice[pollId][voter];
    }

     function getVoteWeight(uint256 pollId, address voter) external view returns (uint256) {
        require(hasVoted[pollId][voter], "Voter has not voted");
        return voteWeight[pollId][voter];     
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