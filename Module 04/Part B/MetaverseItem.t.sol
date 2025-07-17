pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MetaverseItem.sol";

contract MetaverseItemTest is Test {
    MetaverseItem nft;
    address admin = address(0x1);
    address minter = address(0x2);
    address user = address(0x3);
    string baseURI = "ipfs://bafy123/";

    function setUp() public {
        vm.startPrank(admin);
        nft = new MetaverseItem("Metaverse Item", "MITM", baseURI, admin);
        nft.grantRole(keccak256("MINTER_ROLE"), minter);
        vm.stopPrank();
    }


    function testTokenURIReturnsExpectedLink() public {
        vm.prank(minter);
        nft.mint(user);
        assertEq(nft.tokenURI(1), string(abi.encodePacked(baseURI, "1.json")));
    }

    function testSetBaseURIUpdatesCorrectly() public {
        string memory newBaseURI = "ipfs://newcid/";
        vm.prank(admin);
        nft.setBaseURI(newBaseURI);
        vm.prank(minter);
        nft.mint(user);
        assertEq(nft.tokenURI(1), string(abi.encodePacked(newBaseURI, "1.json")));
    }
}