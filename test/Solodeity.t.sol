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
}
