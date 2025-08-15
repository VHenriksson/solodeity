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

    function currentMaxNumber() external view returns (uint16 maxNum) {
        return currentRound.maxNumber;
    }

    function currentPhase() external view returns (string memory) {
        if (currentRound.maxNumber == 0) return "no-round";
        if (currentRound.commitEndTime == 0) return "commit";
        if (block.timestamp <= currentRound.revealEnd) return "reveal";
        if (!currentRound.settled) return "await-settle";
        return "settled";
    }

    function currentParticipantCount() external view returns (uint256 currentCount, uint256 maxCount) {
        currentCount = participants.length;
        maxCount = uint256(currentRound.maxNumber) + 1;
    }
}