SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LootCrate1155.sol";

contract LootCrate1155Test is Test {
    LootCrate1155 crate;
    address admin = address(0x1);
    address user = address(0x2);
    uint256 constant CRATE_PRICE = 0.02 ether;

    function setUp() public {
        vm.prank(admin);
        crate = new LootCrate1155(admin);
    }

    function testOpenCrateRevertsWithWrongETH() public {
        vm.deal(user, 0.01 ether);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(LootCrate1155.InsufficientPayment.selector));
        crate.openCrate{value: 0.01 ether}(1);
    }

    function testOpenCrateMintsCorrectly() public {
        vm.deal(user, CRATE_PRICE);
        vm.prank(user);
        crate.openCrate{value: CRATE_PRICE}(1);
        assertTrue(crate.balanceOf(user, 1) > 0 || crate.balanceOf(user, 2) > 0);
    }

    function testMintBatchRespectsCaps() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        amounts[0] = 5001;
        amounts[1] = 1;

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(LootCrate1155.ExceedsMaxSupply.selector));
        crate.mintBatch(user, ids, amounts);
    }
}