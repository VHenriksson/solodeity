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

}
