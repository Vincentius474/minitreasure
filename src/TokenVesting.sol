// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenVesting
 * @notice Manages vesting schedules with cliff and linear release.
 */
contract TokenVesting is Ownable {

    using SafeERC20 for IERC20;

    struct VestingSchedule {
        address beneficiary;
        uint256 start;
        uint256 cliff;
        uint256 duration;
        uint256 amount;
        uint256 released;
        bool revocable;
        bool revoked;
    }

    IERC20 public immutable token;
    uint256 public nextScheduleId;
    mapping(uint256 => VestingSchedule) public schedules;

    event ScheduleCreated(uint256 indexed scheduleId, address indexed beneficiary, uint256 amount);
    event TokensReleased(uint256 indexed scheduleId, address indexed beneficiary, uint256 amount);
    event ScheduleRevoked(uint256 indexed scheduleId, uint256 unvestedAmount);

    constructor(address _token, address initialOwner) Ownable(initialOwner) {
        require(_token != address(0), "Invalid token");
        token = IERC20(_token);
    }

    /// @notice Create a new vesting schedule
    function createSchedule(address beneficiary, uint256 start, uint256 cliffDuration, uint256 duration, uint256 amount, bool revocable) 
    external onlyOwner returns (uint256) {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(duration > 0, "Duration must be > 0");
        require(cliffDuration <= duration, "Cliff exceeds duration");
        require(amount > 0, "Amount must be > 0");

        uint256 scheduleId = nextScheduleId++;
        schedules[scheduleId] = VestingSchedule({
            beneficiary: beneficiary,
            start: start,
            cliff: start + cliffDuration,
            duration: duration,
            amount: amount,
            released: 0,
            revocable: revocable,
            revoked: false
        });

        token.safeTransferFrom(msg.sender, address(this), amount);
        emit ScheduleCreated(scheduleId, beneficiary, amount);
        return scheduleId;
    }

    /// @notice Compute currently vested amount
    function computeVested(uint256 scheduleId) public view returns (uint256) {
        VestingSchedule storage s = schedules[scheduleId];
        if (block.timestamp < s.cliff) return 0;
        if (block.timestamp >= s.start + s.duration) return s.amount;
        uint256 elapsed = block.timestamp - s.start;
        return (s.amount * elapsed) / s.duration;
    }

    /// @notice Compute releasable amount
    function computeReleasable(uint256 scheduleId) public view returns (uint256) {
        return computeVested(scheduleId) - schedules[scheduleId].released;
    }

    /// @notice Release vested tokens to beneficiary
    function release(uint256 scheduleId) external {
        VestingSchedule storage s = schedules[scheduleId];
        require(msg.sender == s.beneficiary || msg.sender == owner(), "Not authorized");

        uint256 releasable = computeReleasable(scheduleId);
        require(releasable > 0, "Nothing to release");

        s.released += releasable;
        token.safeTransfer(s.beneficiary, releasable);
        emit TokensReleased(scheduleId, s.beneficiary, releasable);
    }

    /// @notice Revoke a revocable schedule
    function revoke(uint256 scheduleId) external onlyOwner {
        VestingSchedule storage s = schedules[scheduleId];
        require(s.revocable, "Not revocable");
        require(!s.revoked, "Already revoked");

        uint256 vested = computeVested(scheduleId);
        uint256 unvested = s.amount - vested - s.released;

        s.revoked = true;
        if (unvested > 0) {
            token.safeTransfer(owner(), unvested);
        }
        emit ScheduleRevoked(scheduleId, unvested);
    }
    
}