// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract TimeLockedWallet is ReentrancyGuard, Pausable, Ownable(msg.sender) {
    using Address for address payable;

    struct Lock {
        uint256 amount;
        address depositor;
        uint256 unlockTime;
        bool claimed;
    }

    uint256 public constant MIN_DELAY = 1 days;
    uint256 public constant GRACE_PERIOD = 7 days;
    uint256 public constant BATCH_LIMIT = 32;
    uint256 public protocolFeeBalance;

    uint256 private nextLockId = 1;

    mapping(address => mapping(uint256 => Lock)) public locks;
    mapping(address => uint256[]) public lockIds;

    event LockCreated(
        address indexed depositor,
        address indexed beneficiary,
        uint256 indexed lockId,
        uint256 amount,
        uint256 unlockTime
    );
    event LockClaimed(
        address indexed beneficiary,
        address indexed recipient,
        uint256 indexed lockId,
        uint256 amount,
        uint256 fee
    );
    event LockReclaimed(
        address indexed depositor,
        uint256 indexed lockId,
        uint256 amount
    );
    event FeeWithdrawn(address indexed admin, uint256 amount);

    error ZeroAmount();
    error UnlockTooSoon();
    error InvalidLock();
    error AlreadyClaimed();
    error NotBeneficiary();
    error NotDepositor();
    error LockNotMature();
    error GracePeriodNotOver();
    error BatchTooLarge();
    error FeeTransferFailed();
    error TransferFailed();
    error InvalidRecipient();

    function createLock(
        address beneficiary,
        uint256 unlockTime
    ) external payable whenNotPaused {
        if (msg.value == 0) revert ZeroAmount();
        if (unlockTime < block.timestamp + MIN_DELAY) revert UnlockTooSoon();
        if (beneficiary == address(0)) revert InvalidLock();

        uint256 lockId = nextLockId++;
        locks[beneficiary][lockId] = Lock({
            amount: msg.value,
            depositor: msg.sender,
            unlockTime: unlockTime,
            claimed: false
        });

        lockIds[beneficiary].push(lockId);

        emit LockCreated(msg.sender, beneficiary, lockId, msg.value, unlockTime);
    }

    function claim(
        uint256 lockId,
        address payable recipient
    ) external nonReentrant whenNotPaused {
        Lock storage lock = locks[msg.sender][lockId];
        if (lock.amount == 0) revert InvalidLock();
        if (lock.claimed) revert AlreadyClaimed();
        if (block.timestamp < lock.unlockTime) revert LockNotMature();

        lock.claimed = true;

        uint256 fee = lock.amount / 100; // 1%
        uint256 payout = lock.amount - fee;
        protocolFeeBalance += fee;

        if (recipient == address(0)) recipient = payable(msg.sender);

        recipient.sendValue(payout); // replaces low-level call

        emit LockClaimed(msg.sender, recipient, lockId, payout, fee);
    }

    function batchClaim(
        uint256[] calldata ids,
        address payable recipient
    ) external nonReentrant whenNotPaused {
        if (ids.length == 0 || ids.length > BATCH_LIMIT) revert BatchTooLarge();
        uint256 totalPayout;
        uint256 totalFee;

        for (uint256 i = 0; i < ids.length; i++) {
            Lock storage lock = locks[msg.sender][ids[i]];
            if (lock.amount == 0) revert InvalidLock();
            if (lock.claimed) revert AlreadyClaimed();
            if (block.timestamp < lock.unlockTime) revert LockNotMature();

            lock.claimed = true;

            uint256 fee = lock.amount / 100;
            totalFee += fee;
            totalPayout += (lock.amount - fee);
        }

        protocolFeeBalance += totalFee;
        if (recipient == address(0)) recipient = payable(msg.sender);

        recipient.sendValue(totalPayout); // replaces low-level call

        for (uint256 i = 0; i < ids.length; i++) {
            emit LockClaimed(
                msg.sender,
                recipient,
                ids[i],
                locks[msg.sender][ids[i]].amount -
                    locks[msg.sender][ids[i]].amount / 100,
                locks[msg.sender][ids[i]].amount / 100
            );
        }
    }

    function reclaim(
        address beneficiary,
        uint256 lockId
    ) external nonReentrant whenNotPaused {
        Lock storage lock = locks[beneficiary][lockId];
        if (lock.amount == 0) revert InvalidLock();
        if (lock.claimed) revert AlreadyClaimed();
        if (lock.depositor != msg.sender) revert NotDepositor();
        if (block.timestamp < lock.unlockTime + GRACE_PERIOD)
            revert GracePeriodNotOver();

        lock.claimed = true;

        uint256 fee = lock.amount / 100;
        uint256 payout = lock.amount - fee;
        protocolFeeBalance += fee;

        payable(msg.sender).sendValue(payout); // replaces low-level call

        emit LockReclaimed(msg.sender, lockId, payout);
    }

    function withdrawFees(
        address payable recipient
    ) external onlyOwner nonReentrant whenNotPaused {
        if (recipient == address(0)) revert InvalidRecipient();

        uint256 amount = protocolFeeBalance;
        protocolFeeBalance = 0;

        recipient.sendValue(amount); // replaces low-level call

        emit FeeWithdrawn(msg.sender, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getLockIds(
        address beneficiary
    ) external view returns (uint256[] memory) {
        return lockIds[beneficiary];
    }

    function getLock(
        address beneficiary,
        uint256 lockId
    ) external view returns (Lock memory) {
        return locks[beneficiary][lockId];
    }

    receive() external payable {
        revert("Use createLock");
    }

    fallback() external payable {
        revert("Use createLock");
    }
}
