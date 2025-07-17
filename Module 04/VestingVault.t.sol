pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VestingToken.sol";
import "../src/VestingVault.sol";

contract VestingVaultTest is Test {
    VestingToken token;
    VestingVault vault;
    address admin = address(0x1);
    address beneficiary = address(0x2);
    uint64 cliff = uint64(block.timestamp + 1 days);
    uint64 duration = 365 days;
    uint256 amount = 1000 * 10**18;

    event Claimed(address indexed beneficiary, uint256 scheduleId, uint256 amount);

    function setUp() public {
        vm.startPrank(admin);
        token = new VestingToken("Vesting Token", "VTK", admin, address(0x3));
        vault = new VestingVault(token, admin);
        vm.stopPrank();
    }

    function testNonAdminCannotCreateSchedule() public {
        vm.prank(beneficiary);
        vm.expectRevert();
        vault.createSchedule(beneficiary, cliff, duration, amount);
    }

    function testClaimRevertsForNonBeneficiary() public {
        vm.prank(admin);
        vault.createSchedule(beneficiary, cliff, duration, amount);
        vm.warp(cliff + duration / 2);
        vm.prank(address(0x4));
        vm.expectRevert(abi.encodeWithSelector(VestingVault.NotBeneficiary.selector));
        vault.claim(1);
    }

}