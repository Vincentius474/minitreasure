// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MiniTreasure.sol";

contract MiniTreasureTest is Test {
    
    MiniTreasure token;
    address owner = address(0x1);
    address alice = address(0x2);

    function setUp() public {
        token = new MiniTreasure(1_000_000 * 10**18, owner);
    }

    function test_InitialSupply() public view {
        assertEq(token.totalSupply(), 1_000_000 * 10**18);
        assertEq(token.balanceOf(owner), 1_000_000 * 10**18);
    }

    function test_Mint() public {
        vm.prank(owner);
        token.mint(alice, 100 * 10**18);
        assertEq(token.balanceOf(alice), 100 * 10**18);
    }

    function test_MintExceedsMaxSupply() public {
        vm.prank(owner);
        vm.expectRevert("Exceeds max supply");
        token.mint(alice, 999_000_001 * 10**18);
    }

    function test_Burn() public {
        vm.prank(owner);
        token.burn(100 * 10**18);
        assertEq(token.totalSupply(), 999_900 * 10**18);
    }

}