// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Solodeity is Ownable, ReentrancyGuard {

    constructor() Ownable(msg.sender) {}

    struct Round {
        uint16 maxNumber;        
        uint64 revealDuration;   
        uint64 revealEnd;        
        uint128 stakeWei;        
        uint128 depositWei;      
        bool settled;
        uint16 winningNumber;    
        address winner;
        uint64 commitEndTime;  
    }

    Round public currentRound;

    address[] public participants;

    event RoundStarted(
        uint16 maxNumber,
        uint64 revealDuration,
        uint128 stakeWei,
        uint128 depositWei
    );

    /// @notice Start a new game round with specified parameters
    /// @dev Only the contract owner can call this function. Previous round must be settled first.
    /// @param maxNum Maximum number players can commit (1 to maxNum). Also sets max participants to maxNum+1
    /// @param revealDuration How long players have to reveal after commit phase ends (in seconds)
    /// @param stakeWei Amount each player pays that goes into the prize pool (in wei)
    /// @param depositWei Amount each player pays as deposit, refunded on successful reveal (in wei)
    function startRound(
        uint16 maxNum,       
        uint64 revealDuration,
        uint128 stakeWei,
        uint128 depositWei
    ) external onlyOwner {
        require(revealDuration > 0 && maxNum > 0, "invalid params");

        // Prevent overlapping games - previous game must be settled
        // If maxNumber is 0, it means this is the very first game
        require(currentRound.settled || currentRound.maxNumber == 0, "prev not settled");

        currentRound = Round({
            maxNumber: maxNum,
            revealDuration: revealDuration,
            revealEnd: 0, // will be set when commit phase ends
            stakeWei: stakeWei,
            depositWei: depositWei,
            settled: false,
            winningNumber: 0, // placeholder for no winner yet
            winner: address(0),
            commitEndTime: 0 // will be set when maxNumber+1 participants reached
        });

        emit RoundStarted(maxNum, revealDuration, stakeWei, depositWei);
    }

    /// @notice Get the maximum number for the current round
    /// @dev Returns 0 if no round has been started yet
    /// @return maxNum The highest number players can commit to (1 to maxNum)
    function currentMaxNumber() external view returns (uint16 maxNum) {
        return currentRound.maxNumber;
    }

    /// @notice Get the current phase of the game
    /// @dev Phases progress: no-round → commit → reveal → await-settle → settled
    /// @return phase Current game phase as a string
    function currentPhase() external view returns (string memory) {
        if (currentRound.maxNumber == 0) return "no-round";
        if (currentRound.commitEndTime == 0) return "commit";
        if (block.timestamp <= currentRound.revealEnd) return "reveal";
        if (!currentRound.settled) return "await-settle";
        return "settled";
    }

    /// @notice Get current and maximum participant counts for the active round
    /// @dev maxCount is always maxNumber, commit phase ends when currentCount reaches maxCount
    /// @return currentCount Number of players who have committed so far
    /// @return maxCount Maximum participants allowed (triggers end of commit phase)
    function currentParticipantCount() external view returns (uint256 currentCount, uint256 maxCount) {
        currentCount = participants.length;
        maxCount = uint256(currentRound.maxNumber);
    }
}