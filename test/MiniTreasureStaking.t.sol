// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MiniTreasure.sol";
import "../src/MiniTreasureStaking.sol";

contract MiniTreasureStakingTest is Test {
    MiniTreasure token;
    MiniTreasureStaking staking;
    address owner = address(0x1);
    address alice = address(0x2);

    function setUp() public {
        vm.startPrank(owner);
        token = new MiniTreasure(10_000_000 * 10**18, owner);
        staking = new MiniTreasureStaking(address(token), address(token), owner);

        // Fund staking rewards
        token.approve(address(staking), 5_000_000 * 10**18);
        staking.fundRewards(5_000_000 * 10**18);

        // Give alice tokens
        token.transfer(alice, 100_000 * 10**18);
        vm.stopPrank();

        vm.prank(alice);
        token.approve(address(staking), type(uint256).max);
    }

    function test_Stake() public {
        vm.prank(alice);
        staking.stake(10_000 * 10**18, 30 days);

        (uint256 amount,,,,bool active) = staking.userStakes(alice, 0);
        assertEq(amount, 10_000 * 10**18);
        assertTrue(active);
        assertEq(staking.totalStaked(alice), 10_000 * 10**18);
    }

    function test_PendingReward() public {
        vm.prank(alice);
        staking.stake(10_000 * 10**18, 30 days);

        vm.warp(block.timestamp + 30 days);
        uint256 reward = staking.pendingReward(alice, 0);
        // 5% APY for 30 days ≈ 41 tokens
        assertGt(reward, 0);
    }

    function test_UnstakeAfterLock() public {
        vm.prank(alice);
        staking.stake(10_000 * 10**18, 30 days);

        vm.warp(block.timestamp + 30 days + 1);
        uint256 balanceBefore = token.balanceOf(alice);

        vm.prank(alice);
        staking.unstake(0);

        assertGt(token.balanceOf(alice), balanceBefore); // Got principal + reward
    }

    function test_RevertUnstakeBeforeLock() public {
        vm.prank(alice);
        staking.stake(10_000 * 10**18, 90 days);

        vm.prank(alice);
        vm.expectRevert("Still locked");
        staking.unstake(0);
    }

    function test_EmergencyUnstake() public {
        uint256 aliceStart = token.balanceOf(alice);

        vm.prank(alice);
        staking.stake(10_000 * 10**18, 90 days);

        vm.prank(alice);
        staking.emergencyUnstake(0);

        assertEq(token.balanceOf(alice), aliceStart - 5_000 * 10**18);
    }
}