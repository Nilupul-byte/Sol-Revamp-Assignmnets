// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title GameEconomyV2
 * @dev Upgraded version with batch material purchasing
 */
contract GameEconomyV2 is 
    Initializable, 
    ERC1155Upgradeable, 
    AccessControlUpgradeable, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    UUPSUpgradeable 
{
    // Role definitions
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant GAME_ADMIN_ROLE = keccak256("GAME_ADMIN_ROLE");

    // Token ID constants
    uint256 public constant CURRENCY_ID = 0;
    uint256 public constant FIRST_MATERIAL_ID = 1;
    
    // State variables
    uint256 public currencyPricePerUnit;
    uint256 public nextUniqueId;
    
    mapping(uint256 => uint256) public materialPrice;
    mapping(uint256 => uint256) public activeRecipe;
    mapping(uint256 => bool) public isMaterial;
    
    // Events
    event CurrencyBought(address indexed buyer, uint256 amount, uint256 ethPaid);
    event MaterialPurchased(address indexed buyer, uint256 materialId, uint256 amount, uint256 currencyBurned);
    event MaterialsBatchPurchased(address indexed buyer, uint256[] materialIds, uint256[] amounts, uint256 totalCurrencyBurned);
    event Crafted(address indexed crafter, uint256 craftedId, uint256[] materialsUsed, uint256[] amounts);
    event Withdrawn(address indexed to, uint256 amount);
    event MaterialPriceSet(uint256 indexed materialId, uint256 price);
    event RecipeSet(uint256[] materialIds, uint256[] amounts);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Buy currency with ETH at fixed price
     */
    function buyCurrency(uint256 amount) external payable whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 totalCost = amount * currencyPricePerUnit;
        require(msg.value == totalCost, "Incorrect ETH amount");

        _mint(msg.sender, CURRENCY_ID, amount, "");
        
        emit CurrencyBought(msg.sender, amount, msg.value);
    }

    /**
     * @dev Admin function to withdraw ETH from contract
     */
    function withdraw(address to, uint256 amount) external onlyRole(GAME_ADMIN_ROLE) whenNotPaused nonReentrant {
        require(to != address(0), "Invalid withdrawal address");
        require(amount > 0, "Amount must be greater than 0");
        require(address(this).balance >= amount, "Insufficient contract balance");

        (bool success, ) = to.call{value: amount}("");
        require(success, "ETH transfer failed");

        emit Withdrawn(to, amount);
    }

    /**
     * @dev Set price for a material
     */
    function setMaterialPrice(uint256 materialId, uint256 price) external onlyRole(GAME_ADMIN_ROLE) {
        require(materialId >= FIRST_MATERIAL_ID && materialId < nextUniqueId, "Invalid material ID");
        require(price > 0, "Price must be greater than 0");
        
        materialPrice[materialId] = price;
        isMaterial[materialId] = true;
        
        emit MaterialPriceSet(materialId, price);
    }

    /**
     * @dev Buy materials with currency (single material)
     */
    function buyMaterial(uint256 materialId, uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(isMaterial[materialId], "Invalid material ID");
        require(materialPrice[materialId] > 0, "Material not available");

        uint256 totalCost = amount * materialPrice[materialId];
        require(balanceOf(msg.sender, CURRENCY_ID) >= totalCost, "Insufficient currency");

        _burn(msg.sender, CURRENCY_ID, totalCost);
        _mint(msg.sender, materialId, amount, "");

        emit MaterialPurchased(msg.sender, materialId, amount, totalCost);
    }

    /**
     * @dev NEW V2 FEATURE: Buy multiple materials in a single transaction
     * @param materialIds Array of material IDs to purchase
     * @param amounts Array of amounts to purchase for each material
     */
    function buyMaterialsBatch(uint256[] memory materialIds, uint256[] memory amounts) external whenNotPaused {
        require(materialIds.length == amounts.length, "Mismatched arrays");
        require(materialIds.length > 0, "Empty batch");
        require(materialIds.length <= 50, "Batch too large"); // Prevent gas issues

        uint256 totalCost = 0;

        // Calculate total cost and validate inputs
        for (uint256 i = 0; i < materialIds.length; i++) {
            require(amounts[i] > 0, "Amount must be greater than 0");
            require(isMaterial[materialIds[i]], "Invalid material ID");
            require(materialPrice[materialIds[i]] > 0, "Material not available");
            
            totalCost += amounts[i] * materialPrice[materialIds[i]];
        }

        require(balanceOf(msg.sender, CURRENCY_ID) >= totalCost, "Insufficient currency");

        // Burn currency first (checks-effects-interactions)
        _burn(msg.sender, CURRENCY_ID, totalCost);

        // Mint all materials
        for (uint256 i = 0; i < materialIds.length; i++) {
            _mint(msg.sender, materialIds[i], amounts[i], "");
        }

        emit MaterialsBatchPurchased(msg.sender, materialIds, amounts, totalCost);
    }

    /**
     * @dev Set the active crafting recipe
     */
    function setRecipe(uint256[] memory materialIds, uint256[] memory amounts) external onlyRole(GAME_ADMIN_ROLE) {
        require(materialIds.length == amounts.length, "Mismatched arrays");
        require(materialIds.length > 0, "Empty recipe");

        for (uint256 i = 0; i < materialIds.length; i++) {
            require(isMaterial[materialIds[i]], "Invalid material in recipe");
            require(amounts[i] > 0, "Invalid amount in recipe");
            activeRecipe[materialIds[i]] = amounts[i];
        }

        emit RecipeSet(materialIds, amounts);
    }

    /**
     * @dev Craft an item using the active recipe
     */
    function craft() external whenNotPaused returns (uint256 craftedId) {
        uint256[] memory materialsUsed = new uint256[](100);
        uint256[] memory amountsUsed = new uint256[](100);
        uint256 materialCount = 0;

        for (uint256 i = FIRST_MATERIAL_ID; i < nextUniqueId; i++) {
            if (activeRecipe[i] > 0) {
                require(balanceOf(msg.sender, i) >= activeRecipe[i], "Insufficient materials");
                materialsUsed[materialCount] = i;
                amountsUsed[materialCount] = activeRecipe[i];
                materialCount++;
            }
        }

        require(materialCount > 0, "No active recipe");

        for (uint256 i = 0; i < materialCount; i++) {
            _burn(msg.sender, materialsUsed[i], amountsUsed[i]);
        }

        craftedId = nextUniqueId;
        nextUniqueId++;
        
        _mint(msg.sender, craftedId, 1, "");

        uint256[] memory finalMaterialsUsed = new uint256[](materialCount);
        uint256[] memory finalAmountsUsed = new uint256[](materialCount);
        for (uint256 i = 0; i < materialCount; i++) {
            finalMaterialsUsed[i] = materialsUsed[i];
            finalAmountsUsed[i] = amountsUsed[i];
        }

        emit Crafted(msg.sender, craftedId, finalMaterialsUsed, finalAmountsUsed);
    }

    /**
     * @dev Pause contract operations
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause contract operations
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Get contract's ETH balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Check recipe requirements for given materials
     */
    function getRecipeRequirements(uint256[] memory materialIds) external view returns (uint256[] memory) {
        uint256[] memory requirements = new uint256[](materialIds.length);
        for (uint256 i = 0; i < materialIds.length; i++) {
            requirements[i] = activeRecipe[materialIds[i]];
        }
        return requirements;
    }

    /**
     * @dev Get the version of the contract (V2 feature)
     */
    function version() external pure returns (string memory) {
        return "2.0.0";
    }

    /**
     * @dev Required override for UUPS upgradeability
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    /**
     * @dev Override supportsInterface
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155Upgradeable, AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}