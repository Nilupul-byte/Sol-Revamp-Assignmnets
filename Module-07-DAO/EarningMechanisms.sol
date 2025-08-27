// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ParticipationToken.sol";

contract EarningMechanisms is AccessControl, ReentrancyGuard {
    bytes32 public constant EPOCH_UPDATER_ROLE =
        keccak256("EPOCH_UPDATER_ROLE");

    ParticipationToken public token;

    uint256 public constant EPOCH_DURATION = 1 weeks;
    uint256 public currentEpoch;
    uint256 public epochStartTime;

    // Funding mechanism constants
    uint256 public constant TOKENS_PER_ETH = 1000; // 1 token per 0.001 ETH
    uint256 public constant MAX_FUNDING_TOKENS_PER_EPOCH = 1000 * 1e18;
    uint256 public constant MIN_FUNDING_AMOUNT = 0.001 ether;

    // Check-in mechanism constants
    uint256 public constant CHECK_IN_TOKENS = 10 * 1e18;

    // Track user participation per epoch
    mapping(address => mapping(uint256 => uint256)) public userFundingPerEpoch;
    mapping(address => mapping(uint256 => bool)) public hasCheckedIn;

    event TreasuryFunded(
        address indexed user,
        uint256 amount,
        uint256 tokensEarned,
        uint256 epoch
    );
    event CheckedIn(address indexed user, uint256 tokensEarned, uint256 epoch);
    event EpochAdvanced(uint256 newEpoch, uint256 timestamp);

    constructor(ParticipationToken _token) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EPOCH_UPDATER_ROLE, msg.sender);

        token = _token;
        currentEpoch = 1;
        epochStartTime = block.timestamp;
    }

    function fundTreasury() external payable nonReentrant {
        require(
            msg.value >= MIN_FUNDING_AMOUNT,
            "Minimum contribution not met"
        );

        uint256 tokensToMint = (msg.value * TOKENS_PER_ETH) / 1 ether;
        uint256 alreadyEarned = userFundingPerEpoch[msg.sender][currentEpoch];

        require(
            alreadyEarned + tokensToMint <= MAX_FUNDING_TOKENS_PER_EPOCH,
            "Epoch funding cap exceeded"
        );

        userFundingPerEpoch[msg.sender][currentEpoch] += tokensToMint;
        token.mint(msg.sender, tokensToMint);

        emit TreasuryFunded(msg.sender, msg.value, tokensToMint, currentEpoch);
    }

    function checkIn() external nonReentrant {
        require(
            !hasCheckedIn[msg.sender][currentEpoch],
            "Already checked in this epoch"
        );

        hasCheckedIn[msg.sender][currentEpoch] = true;
        token.mint(msg.sender, CHECK_IN_TOKENS);

        emit CheckedIn(msg.sender, CHECK_IN_TOKENS, currentEpoch);
    }

    function advanceEpoch() external onlyRole(EPOCH_UPDATER_ROLE) {
        require(
            block.timestamp >= epochStartTime + EPOCH_DURATION,
            "Epoch not yet complete"
        );

        currentEpoch++;
        epochStartTime = block.timestamp;

        emit EpochAdvanced(currentEpoch, block.timestamp);
    }

    function withdrawFunds(
        address payable recipient
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        recipient.transfer(balance);
    }
}

