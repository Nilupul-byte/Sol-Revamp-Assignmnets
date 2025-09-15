// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./SimpleEscrow.sol";

contract EscrowFactory is Ownable2Step, Pausable, ReentrancyGuard {
    // F-1: Immutable fee percentage (1%)
    uint256 public immutable feePercent = 1;
    // F-1: Fee recipient address
    address public immutable feeRecipient;
    // F-4: Mapping of depositor to their escrow addresses
    mapping(address => address[]) public escrows;
    // Accumulated fees
    uint256 public totalFees;

    // F-2: Event for escrow creation
    event EscrowCreated(address indexed escrowAddress, address indexed depositor, address indexed payee);

    // F-1: Constructor sets fee recipient and owner
    constructor(address _feeRecipient) Ownable(msg.sender) {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        feeRecipient = _feeRecipient;
    }

    // F-2: Deploy a new SimpleEscrow with CREATE2
    function createEscrow(address _depositor, address _payee, uint256 _deadline, bytes32 _salt)
        external
        whenNotPaused
        returns (address escrowAddress)
    {
        require(_depositor != address(0), "Invalid depositor");
        require(_payee != address(0), "Invalid payee");
        require(_deadline > block.timestamp, "Deadline must be in the future");

        // Deploy new escrow with CREATE2
        SimpleEscrow escrow = new SimpleEscrow{salt: _salt}(address(this), _depositor, _payee, _deadline, feePercent);
        escrowAddress = address(escrow);

        // F-4: Record escrow for depositor
        escrows[_depositor].push(escrowAddress);

        emit EscrowCreated(escrowAddress, _depositor, _payee);
        return escrowAddress;
    }

    // F-3: Predict the address of an escrow contract using CREATE2
    function predictAddress(address _depositor, address _payee, uint256 _deadline, bytes32 _salt)
        external
        view
        returns (address)
    {
        return address(uint160(uint(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            _salt,
            keccak256(abi.encodePacked(
                type(SimpleEscrow).creationCode,
                abi.encode(address(this), _depositor, _payee, _deadline, feePercent)
            ))
        )))));
    }

    // F-4: Get all escrows for a depositor
    function getEscrows(address _depositor) external view returns (address[] memory) {
        return escrows[_depositor];
    }

    // F-5: Pause deployments
    function pause() external onlyOwner {
        _pause();
    }

    // F-5: Unpause deployments
    function unpause() external onlyOwner {
        _unpause();
    }

    // F-6: Withdraw accumulated fees
    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount = totalFees;
        require(amount > 0, "No fees to withdraw");
        totalFees = 0;

        (bool success, ) = payable(feeRecipient).call{value: amount}("");
        require(success, "Fee withdrawal failed");
    }

    // Receive fees from escrows
    receive() external payable {
        totalFees += msg.value;
    }
}
