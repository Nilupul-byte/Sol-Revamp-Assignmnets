// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/EscrowFactory.sol";
import "../src/SimpleEscrow.sol";

contract EscrowTest is Test {
    EscrowFactory factory;
    address feeRecipient = address(0x123);
    address depositor;
    address payee = address(0x789);
    uint256 deadline;
    bytes32 salt = bytes32(uint256(1234));
    uint256 privateKey;

    function setUp() public {
        // Derive depositor address from private key
        privateKey = 0xabc;
        depositor = vm.addr(privateKey);
        // Set up depositor with ETH
        vm.deal(depositor, 100 ether);
        // Set future deadline
        deadline = block.timestamp + 1 days;
        // Deploy factory
        factory = new EscrowFactory(feeRecipient);
    }

    // Test 1: Verify CREATE2 address prediction matches deployed address
    function testPredictAddressMatchesDeployed() public {
        // Predict address
        address predicted = factory.predictAddress(depositor, payee, deadline, salt);
        // Deploy escrow
        vm.prank(depositor);
        address actual = factory.createEscrow(depositor, payee, deadline, salt);
        // Assert addresses match
        assertEq(predicted, actual, "Predicted address does not match deployed address");
    }

    // Test 2: Happy path (fund -> signed release -> correct fee split)
    function testHappyPath() public {
        // Deploy escrow
        vm.prank(depositor);
        address escrowAddress = factory.createEscrow(depositor, payee, deadline, salt);
        SimpleEscrow escrow = SimpleEscrow(escrowAddress);

        // Fund escrow
        vm.prank(depositor);
        escrow.fund{value: 1 ether}();
        assertEq(escrow.depositedAmount(), 1 ether, "Funding amount incorrect");

        // Sign release message
        bytes32 messageHash = keccak256(abi.encode("RELEASE", escrowAddress, 1 ether));
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Debug: Verify the recovered address
        address recovered = ecrecover(ethSignedHash, v, r, s);
        assertEq(recovered, depositor, "Recovered address does not match depositor");

        // Record initial balances
        uint256 payeeInitialBalance = payee.balance;
        uint256 factoryInitialBalance = address(factory).balance;

        // Release funds
        vm.prank(payee);
        escrow.release(1 ether, signature);

        // Check payee received 99% (1 ether - 1% fee)
        uint256 expectedPayeeAmount = (1 ether * 99) / 100;
        assertEq(payee.balance, payeeInitialBalance + expectedPayeeAmount, "Payee received incorrect amount");

        // Check factory received 1% fee
        uint256 expectedFee = (1 ether * 1) / 100;
        assertEq(address(factory).balance, factoryInitialBalance + expectedFee, "Factory received incorrect fee");

        // Check escrow is empty
        assertEq(address(escrow).balance, 0, "Escrow not empty");
        assertTrue(escrow.released(), "Escrow not marked as released");
    }
}