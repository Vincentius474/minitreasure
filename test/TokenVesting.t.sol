// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MiniTreasure.sol";
import "../src/TokenVesting.sol";

contract TokenVestingTest is Test {
    MiniTreasure token;
    TokenVesting vesting;
    address owner = address(0x1);
    address alice = address(0x2);

    function setUp() public {
        token = new MiniTreasure(10_000_000 * 10**18, owner);
        vesting = new TokenVesting(address(token), owner);
        vm.prank(owner);
        token.approve(address(vesting), 1_000_000 * 10**18);
    }

    // function test_CreateSchedule() public {
    //     vm.prank(owner);
    //     uint256 id = vesting.createSchedule(alice, block.timestamp, 30 days, 365 days, 1000 * 10**18, true);
    //     assertEq(id, 0);

    //     // Struct fields in order:
    //     // (address beneficiary, uint256 start, uint256 cliff, uint256 duration,
    //     //  uint256 amount, uint256 released, bool revocable, bool revoked)

    //     (address beneficiary, , , , , , , ) = vesting.schedules(id);
    //     assertEq(beneficiary, alice);
    // }

    function test_CreateSchedule() public {
        vm.prank(owner);
        uint256 id = vesting.createSchedule(alice, block.timestamp, 30 days, 365 days, 1000 * 10**18, true);
        assertEq(id, 0);

        TokenVesting.VestingSchedule memory s = getSchedule(id);
        assertEq(s.beneficiary, alice);
        assertEq(s.amount, 1000 * 10**18);
        assertTrue(s.revocable);
        assertFalse(s.revoked);
    }

    function test_LinearVesting() public {
        vm.prank(owner);
        vesting.createSchedule(alice, block.timestamp, 0, 100 days, 1000 * 10**18, false);

        vm.warp(block.timestamp + 50 days);
        uint256 vested = vesting.computeVested(0);
        assertApproxEqAbs(vested, 500 * 10**18, 1 * 10**17); // ~50%
    }

    function test_Cliff() public {
        vm.prank(owner);
        vesting.createSchedule(alice, block.timestamp, 30 days, 365 days, 1000 * 10**18, false);

        vm.warp(block.timestamp + 15 days);
        assertEq(vesting.computeVested(0), 0); // Cliff not passed

        vm.warp(block.timestamp + 20 days);
        assertGt(vesting.computeVested(0), 0);
    }

    function test_Release() public {
        vm.prank(owner);
        vesting.createSchedule(alice, block.timestamp, 0, 100 days, 1000 * 10**18, false);

        vm.warp(block.timestamp + 100 days);
        vm.prank(alice);
        vesting.release(0);
        assertEq(token.balanceOf(alice), 1000 * 10**18);
    }

    function test_Revoke() public {
        vm.prank(owner);
        vesting.createSchedule(alice, block.timestamp, 0, 100 days, 1000 * 10**18, true);

        vm.warp(block.timestamp + 50 days);
        vm.prank(owner);
        vesting.revoke(0);

        // Alice can still release vested 500 tokens
        vm.prank(alice);
        vesting.release(0);
        assertEq(token.balanceOf(alice), 500 * 10**18);
    }

    function getSchedule(uint256 id) internal view returns (TokenVesting.VestingSchedule memory) {
        (address beneficiary, uint256 start, uint256 cliff, uint256 duration,
        uint256 amount, uint256 released, bool revocable, bool revoked) = vesting.schedules(id);

        return TokenVesting.VestingSchedule({
            beneficiary: beneficiary,
            start: start,
            cliff: cliff,
            duration: duration,
            amount: amount,
            released: released,
            revocable: revocable,
            revoked: revoked
        });
    }

    function test_RevertConstructorZeroToken() public {
        vm.expectRevert("Invalid token");
        new TokenVesting(address(0), owner);
    }

    function test_RevertCreateZeroBeneficiary() public {
        vm.prank(owner);
        vm.expectRevert("Invalid beneficiary");
        vesting.createSchedule(address(0), block.timestamp, 0, 365 days, 1000 * 10**18, false);
    }

    function test_RevertCreateZeroDuration() public {
        vm.prank(owner);
        vm.expectRevert("Duration must be > 0");
        vesting.createSchedule(alice, block.timestamp, 0, 0, 1000 * 10**18, false);
    }

    function test_RevertCreateCliffExceedsDuration() public {
        vm.prank(owner);
        vm.expectRevert("Cliff exceeds duration");
        vesting.createSchedule(alice, block.timestamp, 100 days, 50 days, 1000 * 10**18, false);
    }

    function test_RevertCreateZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert("Amount must be > 0");
        vesting.createSchedule(alice, block.timestamp, 0, 365 days, 0, false);
    }

    function test_ReleaseByOwner() public {
        vm.prank(owner);
        vesting.createSchedule(alice, block.timestamp, 0, 100 days, 1000 * 10**18, false);

        vm.warp(block.timestamp + 100 days);
        vm.prank(owner);  // owner, not alice
        vesting.release(0);

        assertEq(token.balanceOf(alice), 1000 * 10**18); // still goes to alice
    }

    function test_RevertReleaseByStranger() public {
        vm.prank(owner);
        vesting.createSchedule(alice, block.timestamp, 0, 100 days, 1000 * 10**18, false);

        vm.warp(block.timestamp + 100 days);
        vm.prank(address(0xBAD));
        vm.expectRevert("Not authorized");
        vesting.release(0);
    }

    function test_RevertReleaseNothingToRelease() public {
        vm.prank(owner);
        vesting.createSchedule(alice, block.timestamp, 0, 100 days, 1000 * 10**18, false);

        vm.prank(alice);
        vm.expectRevert("Nothing to release");  // Nothing vested yet
        vesting.release(0);
    }

    function test_RevertRevokeNonRevocable() public {
        vm.prank(owner);
        vesting.createSchedule(alice, block.timestamp, 0, 100 days, 1000 * 10**18, false); // revocable = false

        vm.prank(owner);
        vm.expectRevert("Not revocable");
        vesting.revoke(0);
    }

    function test_RevertDoubleRevoke() public {
        vm.prank(owner);
        vesting.createSchedule(alice, block.timestamp, 0, 100 days, 1000 * 10**18, true);

        vm.prank(owner);
        vesting.revoke(0);

        vm.prank(owner);
        vm.expectRevert("Already revoked");
        vesting.revoke(0);
    }

    function test_RevokeAfterFullVest() public {
        vm.prank(owner);
        vesting.createSchedule(alice, block.timestamp, 0, 100 days, 1000 * 10**18, true);

        vm.warp(block.timestamp + 200 days); // fully vested
        vm.prank(owner);
        vesting.revoke(0);

        // Alice can still claim full amount
        vm.prank(alice);
        vesting.release(0);
        assertEq(token.balanceOf(alice), 1000 * 10**18);
    }

}