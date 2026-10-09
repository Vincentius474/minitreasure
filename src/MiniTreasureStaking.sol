// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title MiniTreasureStaking
 * @notice Staking with multiple tiers, lock periods, and reward distribution.
 */
contract MiniTreasureStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lockDuration;
        uint256 rewardRate; // APY in basis points (e.g., 500 = 5%)
        bool active;
    }

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    mapping(address => StakeInfo[]) public userStakes;
    mapping(address => uint256) public totalStaked;
    uint256 public totalRewardsDistributed;

    event Staked(address indexed user, uint256 amount, uint256 lockDuration, uint256 rewardRate);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    // event EmergencyUnstaked(address indexed user, uint256 amount);
    event EmergencyUnstaked(address indexed user, uint256 payout, uint256 penalty);

    constructor(address _stakingToken, address _rewardToken, address initialOwner) Ownable(initialOwner) {
        require(_stakingToken != address(0) && _rewardToken != address(0), "Invalid tokens");
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    /// @notice Stake tokens with a chosen lock period
    function stake(uint256 amount, uint256 lockDuration) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(lockDuration == 30 days || lockDuration == 90 days || lockDuration == 180 days, "Invalid duration");

        uint256 rewardRate = _getRewardRate(lockDuration);

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        userStakes[msg.sender].push(StakeInfo({
            amount: amount,
            startTime: block.timestamp,
            lockDuration: lockDuration,
            rewardRate: rewardRate,
            active: true
        }));

        totalStaked[msg.sender] += amount;
        emit Staked(msg.sender, amount, lockDuration, rewardRate);
    }

    /// @notice Calculate pending rewards for a stake
    function pendingReward(address user, uint256 stakeIndex) public view returns (uint256) {
        StakeInfo storage s = userStakes[user][stakeIndex];
        if (!s.active) return 0;

        uint256 elapsed = block.timestamp - s.startTime;
        if (elapsed > s.lockDuration) elapsed = s.lockDuration;

        return (s.amount * s.rewardRate * elapsed) / (365 days * 10000);
    }

    /// @notice Unstake tokens and claim rewards
    function unstake(uint256 stakeIndex) external nonReentrant {
        StakeInfo storage s = userStakes[msg.sender][stakeIndex];
        require(s.active, "Stake not active");
        require(block.timestamp >= s.startTime + s.lockDuration, "Still locked");

        uint256 reward = pendingReward(msg.sender, stakeIndex);
        uint256 amount = s.amount;

        s.active = false;
        totalStaked[msg.sender] -= amount;

        stakingToken.safeTransfer(msg.sender, amount);
        if (reward > 0) {
            rewardToken.safeTransfer(msg.sender, reward);
            totalRewardsDistributed += reward;
        }

        emit Unstaked(msg.sender, amount, reward);
    }


    // function emergencyUnstake(uint256 stakeIndex) external nonReentrant {
    //     StakeInfo storage s = userStakes[msg.sender][stakeIndex];
    //     require(s.active, "Stake not active");

    //     uint256 reward = pendingReward(msg.sender, stakeIndex);
    //     uint256 amount = s.amount;

    //     s.active = false;
    //     totalStaked[msg.sender] -= amount;

    //     stakingToken.safeTransfer(msg.sender, amount);
    //     // Emergency: no rewards, 50% penalty applied to principal as protocol fee
    //     uint256 penalty = amount / 2;
    //     // Penalty stays in contract (could be redirected to treasury)

    //     emit EmergencyUnstaked(msg.sender, amount);
    // }

    /// @notice Emergency unstake with penalty (50% of rewards forfeited)
    function emergencyUnstake(uint256 stakeIndex) external nonReentrant {
        StakeInfo storage s = userStakes[msg.sender][stakeIndex];
        require(s.active, "Stake not active");

        uint256 amount = s.amount;
        uint256 penalty = amount / 2;
        uint256 payout = amount - penalty;

        s.active = false;
        totalStaked[msg.sender] -= amount;

        // Penalty stays in contract (protocol fee)
        stakingToken.safeTransfer(msg.sender, payout);

        emit EmergencyUnstaked(msg.sender, payout, penalty);
    }

    /// @notice Get reward rate by lock duration
    function _getRewardRate(uint256 lockDuration) internal pure returns (uint256) {
        if (lockDuration == 30 days) return 500;   // 5% APY
        if (lockDuration == 90 days) return 1200;  // 12% APY
        if (lockDuration == 180 days) return 2500; // 25% APY
        return 0;
    }

    /// @notice Fund reward pool (owner only)
    function fundRewards(uint256 amount) external onlyOwner {
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }
}