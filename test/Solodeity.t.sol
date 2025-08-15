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
        assertEq(max, 11); // maxNumber + 1
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
        assertEq(current, 3); // 3 participants committed

        assertEq(game.currentPhase(), "reveal");
    }
}
