
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SimpleEscrow is ReentrancyGuard {
    // Custom errors
    error AlreadyFunded();
    error NotDepositor();
    error InvalidSignature();
    error DeadlineNotPassed();
    error BalanceNotZero();
    error ReleaseAlreadyHappened();
    error InvalidAmount();

    // E-1: Immutable state variables
    address public immutable factory;
    address public immutable depositor;
    address public immutable payee;
    uint256 public immutable deadline;
    uint256 public immutable feePercent;

    // State variables
    uint256 public depositedAmount;
    bool public released;

    // E-2: Event for funding
    event Funded(uint256 amount);
    // E-3: Event for release
    event Released(address indexed payee, uint256 amountAfterFee);

    // E-1: Constructor
    constructor(address _factory, address _depositor, address _payee, uint256 _deadline, uint256 _feePercent) {
        require(_factory != address(0), "Invalid factory address");
        require(_depositor != address(0), "Invalid depositor");
        require(_payee != address(0), "Invalid payee");
        require(_deadline > block.timestamp, "Deadline must be in the future");
        require(_feePercent == 1, "Invalid fee percent");

        factory = _factory;
        depositor = _depositor;
        payee = _payee;
        deadline = _deadline;
        feePercent = _feePercent;
    }

    // E-2: Fund the escrow (single deposit)
    function fund() external payable nonReentrant {
        if (depositedAmount > 0) revert AlreadyFunded();
        if (msg.sender != depositor) revert NotDepositor();
        if (msg.value == 0) revert InvalidAmount();

        depositedAmount = msg.value;
        emit Funded(msg.value);
    }

    // Internal helper to hash release message
    function hashRelease(uint256 _amount) private view returns (bytes32) {
        return keccak256(abi.encode("RELEASE", address(this), _amount));
    }

    // Internal helper to verify signature
    function verify(address _signer, uint256 _amount, bytes memory _signature) internal view returns (bool) {
        require(_signature.length == 65, "Invalid signature length");

        bytes32 messageHash = hashRelease(_amount);
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        // Extract v, r, s from signature
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 65)))
        }

        // Adjust v for compatibility with ecrecover
        if (v < 27) {
            v += 27;
        }

        // Return true if signer matches recovered address
        address recovered = ecrecover(ethSignedHash, v, r, s);
        return _signer == recovered && recovered != address(0);
    }

    // E-3: Release funds to payee with depositor's signature
    function release(uint256 _amount, bytes memory _signature) external nonReentrant {
        if (released) revert ReleaseAlreadyHappened();
        if (_amount > depositedAmount) revert InvalidAmount();
        if (!verify(depositor, _amount, _signature)) revert InvalidSignature();

        released = true;
        uint256 fee = (_amount * feePercent) / 100;
        uint256 amountAfterFee = _amount - fee;

        // Send fee to factory
        (bool feeSuccess, ) = payable(factory).call{value: fee}("");
        require(feeSuccess, "Fee transfer failed");

        // Send remaining amount to payee
        (bool payeeSuccess, ) = payable(payee).call{value: amountAfterFee}("");
        require(payeeSuccess, "Payee transfer failed");

        emit Released(payee, amountAfterFee);
    }

    // E-4: Reclaim funds after deadline
    function reclaim() external nonReentrant {
        if (msg.sender != depositor) revert NotDepositor();
        if (block.timestamp <= deadline) revert DeadlineNotPassed();
        if (released) revert ReleaseAlreadyHappened();
        if (depositedAmount == 0) revert InvalidAmount();

        uint256 amount = depositedAmount;
        depositedAmount = 0;

        (bool success, ) = payable(depositor).call{value: amount}("");
        require(success, "Reclaim failed");
    }

    // E-6: Self-destruct when balance is zero (EIP-6780 compliant)
    function destroy() external {
        if (address(this).balance != 0) revert BalanceNotZero();
        selfdestruct(payable(factory));
    }
}
