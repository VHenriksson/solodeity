// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "forge-std/console.sol";

/// @title Solodeity - Highest Unique Number Commit-Reveal Game
/// @notice A blockchain game where players commit to numbers and the highest unique number wins
/// @dev Uses commit-reveal pattern to prevent front-running. Winner gets prize proportional to their number.
/// @author Viktor Henriksson
contract Solodeity is Ownable, ReentrancyGuard {

    constructor() Ownable(msg.sender) {}

    /// @notice Game round configuration and state
    /// @dev Tracks all parameters and progress for a single game round
    struct Round {
        uint16 maxNumber;        /// Maximum number players can commit to (also max participants)
        uint64 revealDuration;   /// How long reveal phase lasts (in seconds)
        uint64 revealEnd;        /// Timestamp when reveal phase ends
        uint128 stakeWei;        /// Amount each player stakes (goes to winner)
        uint128 depositWei;      /// Refundable deposit (returned on successful reveal)
        bool settled;            /// Whether round has been settled
        bool commitmentPhaseEnded; /// Whether commit phase has ended
    }
    
    /// @notice Player and their revealed number, used for sorting
    /// @dev Helper struct for merge sort algorithm
    struct PlayerAndBet {
        address player;  /// Player's address
        uint16 bet;      /// Number they revealed
    }

    /// @notice Current active round state
    Round public currentRound;

    /// @notice List of players who committed in current round
    /// @dev Reset after each round settlement
    address[] public participants;

    /// @notice Player commitments: address -> commitment hash
    /// @dev Cleared to bytes32(0) after successful reveal
    mapping (address => bytes32) public commits;
    
    /// @notice Player reveals: address -> revealed number
    /// @dev Only set after successful reveal, used to track who revealed what
    mapping (address => uint16) public reveals;

    /// @notice Emitted when a new round starts
    /// @param maxNumber Maximum number players can commit to
    /// @param revealDuration How long reveal phase lasts (seconds)
    /// @param stakeWei Amount each player stakes (wei)
    /// @param depositWei Refundable deposit amount (wei)
    event RoundStarted(
        uint16 maxNumber,
        uint64 revealDuration,
        uint128 stakeWei,
        uint128 depositWei
    );

    /// @notice Emitted when commit phase ends and reveal phase begins
    /// @param revealEnd Timestamp when reveal phase will end
    event CommitPhaseEnded(uint64 revealEnd);

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
            commitmentPhaseEnded: false
        });

        emit RoundStarted(maxNum, revealDuration, stakeWei, depositWei);
    }

    /// @notice Commit to a number with a cryptographic commitment
    /// @dev Players must pay stake + deposit. Commitment phase ends when maxNumber participants join.
    /// @param commitment Hash of keccak256(abi.encode(number, salt)) where number is 1-maxNumber
    function commit(bytes32 commitment) external payable nonReentrant {

        require(currentRound.maxNumber > 0 && !currentRound.commitmentPhaseEnded, "No active round");
        require(commits[msg.sender] == bytes32(0), "Already committed");
        require(msg.value == currentRound.stakeWei + currentRound.depositWei, "Insufficient payment");

        participants.push(msg.sender);
        commits[msg.sender] = commitment;

        // Check if we reached max participants
        if (participants.length >= uint256(currentRound.maxNumber)) {
            currentRound.revealEnd = uint64(block.timestamp + currentRound.revealDuration);
            currentRound.commitmentPhaseEnded = true;
            emit CommitPhaseEnded(currentRound.revealEnd);
        }
    }

    /// @notice Reveal your committed number to participate in the game
    /// @dev Must be called during reveal phase. Deposit is refunded on successful reveal.
    /// @param number The number you committed to (1 to maxNumber)
    /// @param salt The salt you used in your commitment
    function reveal(uint16 number, bytes32 salt) external nonReentrant {
        require(currentRound.commitmentPhaseEnded && currentRound.revealEnd > block.timestamp, "Reveal phase not active");
        require(number > 0 && number <= currentRound.maxNumber, "Invalid number");

        // Verify commitment
        bytes32 expectedCommit = keccak256(abi.encode(number, salt));
        require(commits[msg.sender] == expectedCommit, "Invalid reveal");

        // Store the reveal
        reveals[msg.sender] = number; // Store first revealer for this number
        commits[msg.sender] = bytes32(0); // Clear commitment after reveal

        // Pay deposit back
        uint128 deposit = currentRound.depositWei;
        require(deposit > 0, "No deposit set");
        (bool success, ) = msg.sender.call{value: deposit}("");
        require(success, "Deposit refund failed");
    }

    /// @notice Settle the round and distribute prizes
    /// @dev Can only be called after reveal phase ends. Winner gets stake*winningNumber, owner gets remainder.
    function settle() external nonReentrant {
        require(currentRound.commitmentPhaseEnded && block.timestamp >= currentRound.revealEnd, "Cannot settle yet");
        require(!currentRound.settled, "Already settled");
        
        address winner = this.currentLeader();

        // Transfer prize to winner if exists
        if (winner != address(0)) {
            uint256 prize = currentRound.stakeWei * reveals[winner];
            uint256 leftover = (currentRound.stakeWei * participants.length) - prize;
            (bool success, ) = winner.call{value: prize}("");
            require(success, "Prize transfer failed");
            (success, ) = owner().call{value: leftover}(""); // Owner gets leftover
            require(success, "Leftover transfer failed");
        } else {
            (bool success, ) = owner().call{value: currentRound.stakeWei * participants.length}(""); // No winner, owner gets all
            require(success, "Leftover transfer failed");
        }

        // Reset participants for next round
        delete participants;
        currentRound.settled = true;

    }

    /// @notice Get the revealed number for a specific player
    /// @dev Reverts if player hasn't revealed yet
    /// @param player Address of the player to check
    /// @return The number the player revealed
    function revealFor(address player) external view returns (uint16) {
        uint16 playerReveal = reveals[player];
        require(playerReveal != 0, "No reveal yet");
        return playerReveal;
    }

    /// @notice Get all players who revealed a specific number
    /// @dev Returns an array of addresses in the order they revealed
    /// @param number The number to check (1 to maxNumber)
    /// @return Array of player addresses who revealed this number
    function whoRevealed(uint16 number) external view returns (address[] memory) {
        // First pass: count how many revealed this number
        uint256 count = 0;
        for (uint i = 0; i < participants.length; i++) {
            if (reveals[participants[i]] == number) {
                count++;
            }
        }
        
        // Create array with exact size needed
        address[] memory revealersOfNumber = new address[](count);
        
        // Second pass: fill the array
        uint256 index = 0;
        for (uint i = 0; i < participants.length; i++) {
            if (reveals[participants[i]] == number) {
                revealersOfNumber[index] = participants[i];
                index++;
            }
        }
        
        return revealersOfNumber;
    }

    /// @notice Get a player's commitment hash
    /// @dev Returns bytes32(0) if player hasn't committed or has already revealed
    /// @param player Address of the player to check
    /// @return The commitment hash, or 0 if no active commitment
    function commitmentFor(address player) external view returns (bytes32) {
        return commits[player];
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
        if (!currentRound.commitmentPhaseEnded) return "commit";
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

    /// @notice Sort an array of PlayerAndBet structs in descending order by bet
    /// @dev Uses merge sort algorithm for O(n log n) performance
    /// @param arr Array of PlayerAndBet structs to sort
    /// @return Sorted array in descending order by bet value
    function mergeSort(PlayerAndBet[] memory arr) public pure returns (PlayerAndBet[] memory) {
        if (arr.length <= 1) return arr;  // Base case: 0 or 1 element

        uint256 mid = arr.length / 2;
        PlayerAndBet[] memory left = new PlayerAndBet[](mid);
        PlayerAndBet[] memory right = new PlayerAndBet[](arr.length - mid);

        for (uint256 i = 0; i < mid; i++) {
            left[i] = arr[i];
        }
        for (uint256 i = mid; i < arr.length; i++) {
            right[i - mid] = arr[i];
        }

        left = mergeSort(left);
        right = mergeSort(right);

        return merge(left, right);
    }

    /// @notice Merge two sorted arrays in descending order
    /// @dev Helper function for mergeSort algorithm
    /// @param left First sorted array
    /// @param right Second sorted array
    /// @return Merged array sorted in descending order
    function merge(PlayerAndBet[] memory left, PlayerAndBet[] memory right) internal pure returns (PlayerAndBet[] memory) {
        PlayerAndBet[] memory merged = new PlayerAndBet[](left.length + right.length);
        uint256 i = 0;
        uint256 j = 0;
        uint256 k = 0;
        while (i < left.length && j < right.length) {
            if (left[i].bet >= right[j].bet) {  // Changed to >= for descending order
                merged[k++] = left[i++];
            } else {
                merged[k++] = right[j++];
            }
        }

        // Copy any remaining elements from either half
        while (i < left.length) {
            merged[k++] = left[i++];
        }
        while (j < right.length) {
            merged[k++] = right[j++];
        }

        return merged;
    }

    /// @notice Get the current leader (player with highest unique revealed number)
    /// @dev Uses merge sort to find the highest unique bet among revealed players
    /// @return Address of current leader, or address(0) if no unique leader exists
    function currentLeader() external view returns (address) {

        PlayerAndBet[] memory sortedReveals = new PlayerAndBet[](participants.length);
        for (uint256 i = 0; i < participants.length; i++) {
            sortedReveals[i] = PlayerAndBet({
                player: participants[i],
                bet: reveals[participants[i]]
            });
        }

        sortedReveals = mergeSort(sortedReveals);

        // Find the leader (the first player with a unique highest bet)
        uint256 currentBetIndex = 0;
        while (currentBetIndex < sortedReveals.length) {
            uint256 i = currentBetIndex + 1;
            uint256 bet = sortedReveals[currentBetIndex].bet;
            while (i < sortedReveals.length && sortedReveals[i].bet == bet) {
                i++;
            }
            if (i == currentBetIndex + 1) {
                // Found a unique highest bet
                return sortedReveals[currentBetIndex].player;
            }
            currentBetIndex = i; // Move to next possibly unique bet
        }

        return address(0); // No unique leader found
    }

}