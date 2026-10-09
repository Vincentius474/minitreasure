// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/MiniTreasure.sol";
import "../src/TokenVesting.sol";
import "../src/MiniTreasureStaking.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        // 1. Deploy token (100M initial supply to deployer)
        MiniTreasure token = new MiniTreasure(100_000_000 * 10**18, deployer);
        console.log("MiniTreasure:", address(token));

        // 2. Deploy vesting
        TokenVesting vesting = new TokenVesting(address(token), deployer);
        console.log("TokenVesting:", address(vesting));

        // 3. Deploy staking (same token for staking and rewards for demo)
        MiniTreasureStaking staking = new MiniTreasureStaking(address(token), address(token), deployer);
        console.log("MiniTreasureStaking:", address(staking));

        // 4. Approve vesting to pull tokens and create a sample schedule
        token.approve(address(vesting), 10_000_000 * 10**18);
        uint256 scheduleId = vesting.createSchedule(
            deployer,
            block.timestamp,
            30 days,    // 30-day cliff
            365 days,   // 1-year linear vest
            10_000_000 * 10**18,
            true        // revocable
        );
        console.log("Vesting schedule ID:", scheduleId);

        // 5. Fund staking rewards (5M tokens)
        token.approve(address(staking), 5_000_000 * 10**18);
        staking.fundRewards(5_000_000 * 10**18);

        vm.stopBroadcast();
    }
}