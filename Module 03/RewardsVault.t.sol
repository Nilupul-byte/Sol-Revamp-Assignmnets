pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CommunityToken.sol";
import "../src/RewardsVault.sol";

contract RewardsVaultTest is Test {
    CommunityToken token;
    RewardsVault vault;
    address admin = address(0x1);
    address treasurer = address(0x2);
    address auditor = address(0x3);
    address user = address(0x4);
    address foundationWallet = address(0x5);
    uint256 constant RATE = 1e18 / 0.01 ether;

    event Donation(address indexed donor, uint256 amount);
    event Withdrawal(uint256 amount);

    function setUp() public {
        vm.startPrank(admin);
        token = new CommunityToken("Community Token", "CTK", admin);
        vault = new RewardsVault(token, admin, foundationWallet);
        
        // Grant roles
        token.grantRole(keccak256("MINTER_ROLE"), address(vault));
        vault.grantRole(keccak256("TREASURER_ROLE"), treasurer);
        vault.grantRole(keccak256("PAUSER_ROLE"), auditor);
        vm.stopPrank();
    }

    function testDonateMintsTokensAndEmits() public {
        uint256 donationAmount = 0.1 ether;
        uint256 expectedTokens = (donationAmount * RATE) / 1e18;

        vm.deal(user, donationAmount);
        vm.prank(user);
        vm.expectEmit(true, false, false, true);
        emit Donation(user, donationAmount);
        
        vault.donate{value: donationAmount}();
        
        uint256 userBalance = token.balanceOf(user);
        assertEq(userBalance, expectedTokens, "Incorrect token balance after donation");
    }

    function testWithdrawWorksForTreasurerRevertsForOthers() public {
        uint256 donationAmount = 0.1 ether;
        
        // Fund vault
        vm.deal(user, donationAmount);
        vm.prank(user);
        vault.donate{value: donationAmount}();

        // Non-treasurer should fail
        vm.prank(user);
        vm.expectRevert();
        vault.withdraw(donationAmount);

        // Treasurer should succeed
        uint256 initialBalance = foundationWallet.balance;
        vm.prank(treasurer);
        vm.expectEmit(false, false, false, true);
        emit Withdrawal(donationAmount);
        
        vault.withdraw(donationAmount);
        
        uint256 finalBalance = foundationWallet.balance;
        assertEq(finalBalance - initialBalance, donationAmount, "Incorrect amount withdrawn");
    }

    function testBurnTokens() public {
        uint256 donationAmount = 0.1 ether;
        
        // Fund user with tokens
        vm.deal(user, donationAmount);
        vm.prank(user);
        vault.donate{value: donationAmount}();

        uint256 initialBalance = token.balanceOf(user);
        uint256 burnAmount = initialBalance / 2;

        vm.prank(user);
        token.burn(burnAmount);

        uint256 finalBalance = token.balanceOf(user);
        assertEq(finalBalance, initialBalance - burnAmount, "Incorrect balance after burn");
    }

    function testSetFoundationWalletRevertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(CommunityToken.ZeroAddress.selector));
        vault.setFoundationWallet(address(0));
    }
}