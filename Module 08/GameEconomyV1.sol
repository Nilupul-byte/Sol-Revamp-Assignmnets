// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title GameEconomyV1
 * @dev ERC-1155 based game economy with currency, materials, and crafting
 * Upgradeable via UUPS proxy pattern
 */
contract GameEconomyV1 is 
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
    uint256 public currencyPricePerUnit; // Wei per currency unit
    uint256 public nextUniqueId; // Next ID for crafted items
    
    // Material pricing: materialId => price in currency units
    mapping(uint256 => uint256) public materialPrice;
    
    // Active recipe: materialId => required amount
    mapping(uint256 => uint256) public activeRecipe;
    
    // Track which IDs are materials vs crafted items
    mapping(uint256 => bool) public isMaterial;
    
    // Events
    event CurrencyBought(address indexed buyer, uint256 amount, uint256 ethPaid);
    event MaterialPurchased(address indexed buyer, uint256 materialId, uint256 amount, uint256 currencyBurned);
    event Crafted(address indexed crafter, uint256 craftedId, uint256[] materialsUsed, uint256[] amounts);
    event Withdrawn(address indexed to, uint256 amount);
    event MaterialPriceSet(uint256 indexed materialId, uint256 price);
    event RecipeSet(uint256[] materialIds, uint256[] amounts);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the contract
     * @param admin Address to receive admin roles
     * @param baseURI Base URI for token metadata
     * @param _currencyPricePerUnit Price per currency unit in wei
     * @param materialIds Initial material IDs to set up
     * @param materialPrices Prices for initial materials
     */
    function initialize(
        address admin,
        string memory baseURI,
        uint256 _currencyPricePerUnit,
        uint256[] memory materialIds,
        uint256[] memory materialPrices
    ) public initializer {
        require(admin != address(0), "Invalid admin address");
        require(_currencyPricePerUnit > 0, "Invalid currency price");
        require(materialIds.length == materialPrices.length, "Mismatched arrays");

        __ERC1155_init(baseURI);
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        // Grant roles to admin
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(GAME_ADMIN_ROLE, admin);

        currencyPricePerUnit = _currencyPricePerUnit;
        nextUniqueId = 1000; // Start crafted items from ID 1000

        // Set up initial materials
        for (uint256 i = 0; i < materialIds.length; i++) {
            require(materialIds[i] >= FIRST_MATERIAL_ID && materialIds[i] < nextUniqueId, "Invalid material ID");
            materialPrice[materialIds[i]] = materialPrices[i];
            isMaterial[materialIds[i]] = true;
        }
    }

    /**
     * @dev Buy currency with ETH at fixed price
     * @param amount Amount of currency to buy
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
     * @param to Address to send ETH to
     * @param amount Amount of ETH to withdraw in wei
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
     * @param materialId ID of the material
     * @param price Price in currency units
     */
    function setMaterialPrice(uint256 materialId, uint256 price) external onlyRole(GAME_ADMIN_ROLE) {
        require(materialId >= FIRST_MATERIAL_ID && materialId < nextUniqueId, "Invalid material ID");
        require(price > 0, "Price must be greater than 0");
        
        materialPrice[materialId] = price;
        isMaterial[materialId] = true;
        
        emit MaterialPriceSet(materialId, price);
    }

    /**
     * @dev Buy materials with currency
     * @param materialId ID of material to buy
     * @param amount Amount of material to buy
     */
    function buyMaterial(uint256 materialId, uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(isMaterial[materialId], "Invalid material ID");
        require(materialPrice[materialId] > 0, "Material not available");

        uint256 totalCost = amount * materialPrice[materialId];
        require(balanceOf(msg.sender, CURRENCY_ID) >= totalCost, "Insufficient currency");

        // Burn currency first (checks-effects-interactions)
        _burn(msg.sender, CURRENCY_ID, totalCost);
        
        // Mint materials
        _mint(msg.sender, materialId, amount, "");

        emit MaterialPurchased(msg.sender, materialId, amount, totalCost);
    }

    /**
     * @dev Set the active crafting recipe
     * @param materialIds Array of material IDs required
     * @param amounts Array of amounts required for each material
     */
    function setRecipe(uint256[] memory materialIds, uint256[] memory amounts) external onlyRole(GAME_ADMIN_ROLE) {
        require(materialIds.length == amounts.length, "Mismatched arrays");
        require(materialIds.length > 0, "Empty recipe");

        // Clear existing recipe
        // Note: In a production system, you might want to track recipe versions
        // For simplicity, we'll assume the caller manages this properly
        
        // Set new recipe
        for (uint256 i = 0; i < materialIds.length; i++) {
            require(isMaterial[materialIds[i]], "Invalid material in recipe");
            require(amounts[i] > 0, "Invalid amount in recipe");
            activeRecipe[materialIds[i]] = amounts[i];
        }

        emit RecipeSet(materialIds, amounts);
    }

    /**
     * @dev Craft an item using the active recipe
     * @return craftedId The ID of the newly crafted item
     */
    function craft() external whenNotPaused returns (uint256 craftedId) {
        // Check if user has required materials
        uint256[] memory materialsUsed = new uint256[](100); // Max materials in recipe
        uint256[] memory amountsUsed = new uint256[](100);
        uint256 materialCount = 0;

        // Collect all materials with non-zero recipe amounts
        for (uint256 i = FIRST_MATERIAL_ID; i < nextUniqueId; i++) {
            if (activeRecipe[i] > 0) {
                require(balanceOf(msg.sender, i) >= activeRecipe[i], "Insufficient materials");
                materialsUsed[materialCount] = i;
                amountsUsed[materialCount] = activeRecipe[i];
                materialCount++;
            }
        }

        require(materialCount > 0, "No active recipe");

        // Burn materials (checks-effects-interactions)
        for (uint256 i = 0; i < materialCount; i++) {
            _burn(msg.sender, materialsUsed[i], amountsUsed[i]);
        }

        // Mint unique crafted item
        craftedId = nextUniqueId;
        nextUniqueId++;
        
        _mint(msg.sender, craftedId, 1, "");

        // Create properly sized arrays for event
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
     * @dev Check if a recipe is set for materials
     * @param materialIds Array of material IDs to check
     * @return Array of required amounts (0 if not in recipe)
     */
    function getRecipeRequirements(uint256[] memory materialIds) external view returns (uint256[] memory) {
        uint256[] memory requirements = new uint256[](materialIds.length);
        for (uint256 i = 0; i < materialIds.length; i++) {
            requirements[i] = activeRecipe[materialIds[i]];
        }
        return requirements;
    }

    /**
     * @dev Required override for UUPS upgradeability
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    /**
     * @dev Override supportsInterface to include AccessControl
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155Upgradeable, AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}