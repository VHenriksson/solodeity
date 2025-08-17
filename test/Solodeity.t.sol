// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/Solodeity.sol";

contract SolodeityTest is Test {
    Solodeity game;
    address owner = address(0x1);
    address alice = address(0x2);
    address bob = address(0x3);
    address charlie = address(0x4);

    function setUp() public {
        vm.prank(owner);
        game = new Solodeity();
    }

    function testStartRound() public {
        vm.prank(owner);
        game.startRound(10, 3600, 1 ether, 0.1 ether);
        
        assertEq(game.currentMaxNumber(), 10);
        assertEq(game.currentPhase(), "commit");
        
        (uint256 current, uint256 max) = game.currentParticipantCount();
        assertEq(current, 0);
        assertEq(max, 10); 
    }

    function testCommitPhase() public {
        vm.prank(owner);
        game.startRound(3, 3600, 1 ether, 0.1 ether);

        // Alice commits
        bytes32 aliceCommit = keccak256(abi.encode(1, "alice_salt"));
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        game.commit{value: 1.1 ether}(aliceCommit);

        (uint256 current,) = game.currentParticipantCount();
        assertEq(current, 1);
        assertEq(game.commitmentFor(alice), aliceCommit);

        // Bob commits  
        bytes32 bobCommit = keccak256(abi.encode(2, "bob_salt"));
        vm.deal(bob, 10 ether);
        vm.prank(bob);
        game.commit{value: 1.1 ether}(bobCommit);

        (current,) = game.currentParticipantCount();
        assertEq(current, 2);

        // Charlie commits (3rd player for maxNumber=3, so commit phase should end)
        bytes32 charlieCommit = keccak256(abi.encode(1, "charlie_salt"));
        vm.deal(charlie, 10 ether);
        vm.prank(charlie);
        game.commit{value: 1.1 ether}(charlieCommit);

        (current,) = game.currentParticipantCount();
        assertEq(current, 3); 

        assertEq(game.currentPhase(), "reveal");
    }

    function testCommitNoActiveRound() public {
        // Attempt to commit without starting a round
        bytes32 commitment = keccak256(abi.encode(1, "test_salt"));
        vm.expectRevert("No active round");
        game.commit{value: 1.1 ether}(commitment);

        vm.prank(owner);
        game.startRound(1, 3600, 1 ether, 0.1 ether);
        bytes32 aliceCommit = keccak256(abi.encode(1, "alice_salt"));
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        game.commit{value: 1.1 ether}(aliceCommit);

        // Previous round should have ended
        bytes32 bobCommit = keccak256(abi.encode(2, "bob_salt"));
        vm.deal(bob, 10 ether);
        vm.prank(bob);
        vm.expectRevert("No active round");
        game.commit{value: 1.1 ether}(bobCommit);

    }

    function testDoubleCommit() public {
        vm.prank(owner);
        game.startRound(5, 3600, 1 ether, 0.1 ether);

        // Alice commits
        bytes32 aliceCommit = keccak256(abi.encode(3, "alice_salt"));
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        game.commit{value: 1.1 ether}(aliceCommit);

        // Alice tries to commit again
        bytes32 aliceCommit2 = keccak256(abi.encode(4, "alice_salt"));
        vm.prank(alice);
        vm.expectRevert("Already committed");
        game.commit{value: 1.1 ether}(aliceCommit2);

        // Bob commits
        bytes32 bobCommit = keccak256(abi.encode(5, "bob_salt"));
        vm.deal(bob, 10 ether);
        vm.prank(bob);
        game.commit{value: 1.1 ether}(bobCommit);

        assertEq(game.commitmentFor(alice), aliceCommit);
        assertEq(game.commitmentFor(bob), bobCommit);
    }

    function testInsufficientPayment() public {
        vm.prank(owner);
        game.startRound(5, 3600, 1 ether, 0.1 ether);

        // Alice tries to commit with insufficient payment
        bytes32 aliceCommit = keccak256(abi.encode(3, "alice_salt"));
        vm.deal(alice, 0.5 ether);
        vm.prank(alice);
        vm.expectRevert("Insufficient payment");
        game.commit{value: 0.5 ether}(aliceCommit);
    }


    function testRevealPhase() public {
        vm.prank(owner);
        game.startRound(3, 3600, 1 ether, 0.1 ether);

        // Setup commits with consistent salt encoding
        bytes32 aliceSalt = bytes32("alice_salt");
        bytes32 bobSalt = bytes32("bob_salt");
        bytes32 charlieSalt = bytes32("charlie_salt");
        bytes32 aliceCommit = keccak256(abi.encode(5, aliceSalt));
        bytes32 bobCommit = keccak256(abi.encode(3, bobSalt));
        bytes32 charlieCommit = keccak256(abi.encode(5, charlieSalt));

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);

        vm.prank(alice);
        game.commit{value: 1.1 ether}(aliceCommit);
        
        vm.prank(bob);
        game.commit{value: 1.1 ether}(bobCommit);

        vm.prank(charlie);
        game.commit{value: 1.1 ether}(charlieCommit);

        (uint256 current,) = game.currentParticipantCount();
        assertEq(current, 3); // 3 participants committed

        assertEq(game.currentPhase(), "reveal");

        // Alice reveals
        vm.prank(alice);
        game.reveal(5, aliceSalt);
        assertEq(game.commitmentFor(alice), bytes32(0)); // Alice's commitment should be cleared
        assertEq(game.revealFor(alice), 5); // Alice's reveal should be stored
        
        address[] memory expectedRevealers = new address[](1);
        expectedRevealers[0] = alice;
        assertEq(game.whoRevealed(5), expectedRevealers); // Alice is the first to reveal 5
        
        assertEq(game.currentLeader(), alice); // Alice should be the leader

        vm.prank(bob);
        game.reveal(3, bobSalt);
        assertEq(game.commitmentFor(bob), bytes32(0)); // Bob's commitment should be cleared
        assertEq(game.currentLeader(), alice); // Alice still leads
        
        address[] memory expectedBobRevealers = new address[](1);
        expectedBobRevealers[0] = bob;
        assertEq(game.whoRevealed(3), expectedBobRevealers); // Bob is the first to reveal 3
        
        assertEq(game.revealFor(bob), 3); // Bob's reveal should be stored

        vm.prank(charlie);
        vm.expectRevert("Invalid reveal"); // Charlie reveals with a number not in his commitment
        game.reveal(4, charlieSalt);
        assertEq(game.commitmentFor(charlie), charlieCommit); // Charlie's commitment should remain unchanged
        
        address[] memory noRevealers = game.whoRevealed(4);
        assertEq(noRevealers.length, 0); // No one (successfully) revealed 4
        
        vm.expectRevert("No reveal yet"); // Charlie's reveal should not be stored
        game.revealFor(charlie);

        vm.prank(charlie);
        game.reveal(5, charlieSalt);
        assertEq(game.commitmentFor(charlie), bytes32(0)); // Charlie's commitment should be cleared
        assertEq(game.currentLeader(), bob); // Now bob leads, since he has a unique number
        
        address[] memory expectedMultipleRevealers = new address[](2);
        expectedMultipleRevealers[0] = alice;
        expectedMultipleRevealers[1] = charlie;
        assertEq(game.whoRevealed(5), expectedMultipleRevealers); // Both Alice and Charlie revealed 5
        
        assertEq(game.revealFor(charlie), 5); // Charlie's reveal should be stored
    }

    function testMergeSort() public view {
        // Test the merge sort function
        Solodeity.PlayerAndBet[] memory arr = new Solodeity.PlayerAndBet[](5);
        arr[0] = Solodeity.PlayerAndBet({player: address(0x1), bet: 3});
        arr[1] = Solodeity.PlayerAndBet({player: address(0x2), bet: 1});
        arr[2] = Solodeity.PlayerAndBet({player: address(0x3), bet: 4});
        arr[3] = Solodeity.PlayerAndBet({player: address(0x4), bet: 2});
        arr[4] = Solodeity.PlayerAndBet({player: address(0x5), bet: 5});

        arr = game.mergeSort(arr);

        assertEq(arr[0].bet, 5);
        assertEq(arr[1].bet, 4);
        assertEq(arr[2].bet, 3);
        assertEq(arr[3].bet, 2);
        assertEq(arr[4].bet, 1);
    }
}
