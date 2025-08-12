// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {DaoVaultImplementation, FactoryDao, IDaoVault} from "../src/7_crystalDAO/crystalDAO.sol";

contract Challenge7Test is Test {
    FactoryDao factory;

    address public whitehat = makeAddr("whitehat");
    address public daoManager;
    uint256 daoManagerKey;

    IDaoVault vault;

    function setUp() public {
        (daoManager, daoManagerKey) = makeAddrAndKey("daoManager");
        factory = new FactoryDao();

        vm.prank(daoManager);
        vault = IDaoVault(factory.newWallet());

        // The vault has reached 100 ether in donations
        deal(address(vault), 100 ether);
    }

    function testHack() public {
        vm.startPrank(whitehat, whitehat);

        address target = daoManager; // Send ETH directly to daoManager
        uint256 value = 100 ether; // Send 100 ether

        // Empty calldata for a simple ETH transfer
        bytes memory execOrder = "";

        uint256 deadline = block.timestamp + 1 days;

        DaoVaultImplementation daoVault = DaoVaultImplementation(
            payable(address(vault))
        );

        uint256 nonce = daoVault.nonces(daoManager);

        // Use the EXACT same EXEC_TYPEHASH as defined in the contract
        bytes32 EXEC_TYPEHASH = keccak256(
            "Exec(address target,uint256 value,bytes memory execOrder,uint256 nonce,uint256 deadline)"
        );

        // Hash the struct exactly as done in the contract
        bytes32 structHash = keccak256(
            abi.encode(
                EXEC_TYPEHASH,
                target,
                value,
                execOrder, // Use execOrder directly, not keccak256(execOrder)
                nonce,
                deadline
            )
        );

        bytes32 domainSeparator = daoVault.getDomainSeparator();

        // Use _hashTypedDataV4 format (EIP-712 standard)
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(daoManagerKey, digest);

        daoVault.execWithSignature(v, r, s, target, value, execOrder, deadline);

        vm.stopPrank();

        assertEq(
            daoManager.balance,
            100 ether,
            "The Dao manager's balance should be 100 ether"
        );
    }
}
