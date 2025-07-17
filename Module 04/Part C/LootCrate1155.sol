pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract LootCrate1155 is ERC1155, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    uint256 public constant CRATE_PRICE = 0.02 ether;
    uint256 public constant MAX_SWORDS = 5000;
    uint256 public constant MAX_SHIELDS = 5000;
    uint256 private swordSupply;
    uint256 private shieldSupply;
    uint256 private cosmeticIdCounter = 2;

    error InsufficientPayment();
    error ExceedsMaxSupply();
    error ZeroAddress();

    constructor(address admin) ERC1155("ipfs://lootcrate/") {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function openCrate(uint256 count) external payable whenNotPaused {
        if (msg.value < count * CRATE_PRICE) revert InsufficientPayment();
        
        uint256[] memory ids = new uint256[](count * 2);
        uint256[] memory amounts = new uint256[](count * 2);
        uint256 index;

        for (uint256 i = 0; i < count; i++) {
            uint256 seed = uint256(keccak256(abi.encode(msg.sender, block.timestamp, i)));
            uint256 swordCount = (seed % 3) + 1; // 1-3 swords
            uint256 shieldCount = ((seed >> 128) % 3) + 1; // 1-3 shields

            if (swordSupply + swordCount > MAX_SWORDS || shieldSupply + shieldCount > MAX_SHIELDS) 
                revert ExceedsMaxSupply();

            ids[index] = 1;
            amounts[index++] = swordCount;
            ids[index] = 2;
            amounts[index++] = shieldCount;

            swordSupply += swordCount;
            shieldSupply += shieldCount;

            // 10% chance for cosmetic NFT
            if (seed % 10 == 0) {
                ids[index] = ++cosmeticIdCounter;
                amounts[index++] = 1;
            }
        }

        uint256[] memory finalIds = new uint256[](index);
        uint256[] memory finalAmounts = new uint256[](index);
        for (uint256 i = 0; i < index; i++) {
            finalIds[i] = ids[i];
            finalAmounts[i] = amounts[i];
        }

        _mintBatch(msg.sender, finalIds, finalAmounts, "");
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) 
        external 
        onlyRole(MINTER_ROLE) 
    {
        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] == 1 && swordSupply + amounts[i] > MAX_SWORDS) revert ExceedsMaxSupply();
            if (ids[i] == 2 && shieldSupply + amounts[i] > MAX_SHIELDS) revert ExceedsMaxSupply();
            if (ids[i] > 2 && amounts[i] > 1) revert ExceedsMaxSupply();
            if (ids[i] == 1) swordSupply += amounts[i];
            if (ids[i] == 2) shieldSupply += amounts[i];
        }
        _mintBatch(to, ids, amounts, "");
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC1155, AccessControl) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
}
