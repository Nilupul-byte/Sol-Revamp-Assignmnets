pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./VestingToken.sol";

contract VestingVault is AccessControl, ReentrancyGuard {
    VestingToken public immutable token;
    struct Schedule {
        address beneficiary;
        uint64 cliff;
        uint64 duration;
        uint256 amount;
        uint256 claimed;
    }
    mapping(uint256 => Schedule) public schedules;
    uint256 public scheduleCount;

    error ZeroAddress();
    error InvalidSchedule();
    error NothingToClaim();
    error NotBeneficiary();

    event Claimed(address indexed beneficiary, uint256 scheduleId, uint256 amount);

    constructor(VestingToken _token, address admin) {
        if (address(_token) == address(0) || admin == address(0)) revert ZeroAddress();
        token = _token;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function createSchedule(address beneficiary, uint64 cliff, uint64 duration, uint256 amount) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        if (beneficiary == address(0) || amount == 0 || duration == 0) revert InvalidSchedule();
        schedules[++scheduleCount] = Schedule(beneficiary, cliff, duration, amount, 0);
    }

    function claim(uint256 scheduleId) external nonReentrant {
        Schedule storage schedule = schedules[scheduleId];
        if (schedule.beneficiary != msg.sender) revert NotBeneficiary();
        if (block.timestamp < schedule.cliff) revert NothingToClaim();

        uint256 vested;
        unchecked {
            if (block.timestamp >= schedule.cliff + schedule.duration) {
                vested = schedule.amount;
            } else {
                vested = (schedule.amount * (block.timestamp - schedule.cliff)) / schedule.duration;
            }
        }

        uint256 claimable = vested - schedule.claimed;
        if (claimable == 0) revert NothingToClaim();

        schedule.claimed += claimable;
        token.mint(msg.sender, claimable);
        emit Claimed(msg.sender, scheduleId, claimable);
    }
}