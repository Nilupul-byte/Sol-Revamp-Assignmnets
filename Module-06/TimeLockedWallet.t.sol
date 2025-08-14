// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TimeLockedWallet.sol";

contract TimeLockedWalletTest is Test {
    TimeLockedWallet wallet;
    address depositor = address(0xABCD);
    address beneficiary = address(0xBEEF);
    address another = address(0xCAFE);
    uint256 unlockTime;
    uint256 minDelay = 1 days;

    // Allow test contract to receive ETH
    receive() external payable {}

    function setUp() public {
        wallet = new TimeLockedWallet();
        vm.deal(depositor, 10 ether);
        vm.deal(beneficiary, 0);
        vm.deal(another, 0);

        unlockTime = block.timestamp + minDelay + 1;
    }

    // -------------------------------
    // Lock Creation
    // -------------------------------
    function testCreateLock() public {
        vm.prank(depositor);
        wallet.createLock{value: 1 ether}(beneficiary, unlockTime);

        uint256[] memory ids = wallet.getLockIds(beneficiary);
        assertEq(ids.length, 1);

        TimeLockedWallet.Lock memory lock = wallet.getLock(beneficiary, ids[0]);
        assertEq(lock.amount, 1 ether);
        assertEq(lock.depositor, depositor);
        assertEq(lock.unlockTime, unlockTime);
        assertEq(lock.claimed, false);
    }

    // -------------------------------
    // Single Claim
    // -------------------------------
    function testClaim() public {
        vm.prank(depositor);
        wallet.createLock{value: 1 ether}(beneficiary, unlockTime);

        uint256[] memory ids = wallet.getLockIds(beneficiary);
        vm.warp(unlockTime + 1);

        uint256 balanceBefore = beneficiary.balance;

        vm.prank(beneficiary);
        wallet.claim(ids[0], payable(beneficiary));

        uint256 balanceAfter = beneficiary.balance;
        assertEq(balanceAfter - balanceBefore, 0.99 ether); // 1% fee deducted

        TimeLockedWallet.Lock memory lock = wallet.getLock(beneficiary, ids[0]);
        assertTrue(lock.claimed);
    }

    // -------------------------------
    // Batch Claim
    // -------------------------------
    function testBatchClaim() public {
        vm.startPrank(depositor);
        wallet.createLock{value: 1 ether}(beneficiary, unlockTime);
        wallet.createLock{value: 2 ether}(beneficiary, unlockTime);
        wallet.createLock{value: 3 ether}(beneficiary, unlockTime);
        vm.stopPrank();

        uint256[] memory ids = wallet.getLockIds(beneficiary);
        vm.warp(unlockTime + 1);

        uint256 balanceBefore = beneficiary.balance;

        vm.prank(beneficiary);
        wallet.batchClaim(ids, payable(beneficiary));

        uint256 balanceAfter = beneficiary.balance;
        // Total 6 ETH, minus 1% fee per lock: 1+2+3 = 6; fees = 0.06; payout = 5.94
        assertEq(balanceAfter - balanceBefore, 5.94 ether);

        for (uint256 i = 0; i < ids.length; i++) {
            TimeLockedWallet.Lock memory lock = wallet.getLock(
                beneficiary,
                ids[i]
            );
            assertTrue(lock.claimed);
        }
    }

    // -------------------------------
    // Reclaim after grace period
    // -------------------------------
    function testReclaim() public {
        vm.prank(depositor);
        wallet.createLock{value: 1 ether}(beneficiary, unlockTime);

        uint256[] memory ids = wallet.getLockIds(beneficiary);
        vm.warp(unlockTime + 7 days + 1);

        uint256 balanceBefore = depositor.balance;

        vm.prank(depositor);
        wallet.reclaim(beneficiary, ids[0]);

        uint256 balanceAfter = depositor.balance;
        assertEq(balanceAfter - balanceBefore, 0.99 ether);

        TimeLockedWallet.Lock memory lock = wallet.getLock(beneficiary, ids[0]);
        assertTrue(lock.claimed);
    }

    // -------------------------------
    // Fee withdrawal by admin
    // -------------------------------
    function testWithdrawFees() public {
        vm.prank(depositor);
        wallet.createLock{value: 1 ether}(beneficiary, unlockTime);

        uint256[] memory ids = wallet.getLockIds(beneficiary);
        vm.warp(unlockTime + 1);

        vm.prank(beneficiary);
        wallet.claim(ids[0], payable(beneficiary));

        uint256 feeBalance = wallet.protocolFeeBalance();
        assertEq(feeBalance, 0.01 ether);

        uint256 ownerBalanceBefore = address(this).balance;

        wallet.withdrawFees(payable(address(this)));

        uint256 ownerBalanceAfter = address(this).balance;
        assertEq(ownerBalanceAfter - ownerBalanceBefore, 0.01 ether);
        assertEq(wallet.protocolFeeBalance(), 0);
    }

    // -------------------------------
    // Reentrancy / AlreadyClaimed protection
    // -------------------------------
    function testAlreadyClaimedProtection() public {
        vm.prank(depositor);
        wallet.createLock{value: 1 ether}(beneficiary, unlockTime);

        uint256[] memory ids = wallet.getLockIds(beneficiary);
        vm.warp(unlockTime + 1);

        // First claim succeeds
        vm.prank(beneficiary);
        wallet.claim(ids[0], payable(beneficiary));

        // Second claim should revert with AlreadyClaimed
        vm.expectRevert(TimeLockedWallet.AlreadyClaimed.selector);
        vm.prank(beneficiary);
        wallet.claim(ids[0], payable(beneficiary));
    }
}
