// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract GrantContract is AccessControl, ReentrancyGuard {
    bytes32 public constant GRANT_ADMIN_ROLE = keccak256("GRANT_ADMIN_ROLE");

    struct Grant {
        address recipient;
        uint256 amount;
        bool distributed;
    }

    mapping(uint256 => Grant) public grants;
    uint256 public grantCount;

    event GrantCreated(
        uint256 indexed grantId,
        address indexed recipient,
        uint256 amount
    );
    event GrantDistributed(
        uint256 indexed grantId,
        address indexed recipient,
        uint256 amount
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GRANT_ADMIN_ROLE, msg.sender);
    }

    function createGrant(
        address recipient,
        uint256 amount
    ) external onlyRole(GRANT_ADMIN_ROLE) returns (uint256) {
        uint256 grantId = grantCount++;
        grants[grantId] = Grant(recipient, amount, false);

        emit GrantCreated(grantId, recipient, amount);
        return grantId;
    }

    function distributeGrant(
        uint256 grantId
    ) external nonReentrant onlyRole(GRANT_ADMIN_ROLE) {
        Grant storage grant = grants[grantId];
        require(!grant.distributed, "Grant already distributed");
        require(
            address(this).balance >= grant.amount,
            "Insufficient contract balance"
        );

        grant.distributed = true;
        payable(grant.recipient).transfer(grant.amount);

        emit GrantDistributed(grantId, grant.recipient, grant.amount);
    }

    receive() external payable {}
}
