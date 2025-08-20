// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/GameEconomyV1.sol";
import "../src/GameEconomyV2.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Configuration
        string memory baseURI = "https://api.gameeconomy.io/metadata/{id}.json";
        uint256 currencyPricePerUnit = 0.000001 ether; // 0.001 ETH per currency unit
        uint256[] memory initialMaterials = new uint256[](3);
        initialMaterials[0] = 1; // Wood
        initialMaterials[1] = 2; // Stone  
        initialMaterials[2] = 3; // Iron
        
        uint256[] memory initialPrices = new uint256[](3);
        initialPrices[0] = 10; // Wood: 10 currency units
        initialPrices[1] = 20; // Stone: 20 currency units
        initialPrices[2] = 50; // Iron: 50 currency units

        console.log("\n=== V1 Deployment ===");
        
        // Deploy V1 implementation
        GameEconomyV1 gameEconomyV1Impl = new GameEconomyV1();
        console.log("V1 Implementation deployed to:", address(gameEconomyV1Impl));
        
        // Encode initialization data
        bytes memory initData = abi.encodeWithSelector(
            GameEconomyV1.initialize.selector,
            deployer,
            baseURI,
            currencyPricePerUnit,
            initialMaterials,
            initialPrices
        );
        
        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(gameEconomyV1Impl), initData);
        console.log("Proxy deployed to:", address(proxy));
        
        // Create proxy interface
        GameEconomyV1 gameEconomy = GameEconomyV1(address(proxy));
        
        // Test V1 functionality
        console.log("\n=== Testing V1 Functionality ===");
        
        // Buy currency
        console.log("Buying 150 currency units...");
        gameEconomy.buyCurrency{value: 0.0008 ether}(8000);
        console.log("Currency balance:", gameEconomy.balanceOf(deployer, 0));

        // Set a recipe (Wood: 5, Stone: 3, Iron: 1)
        console.log("Setting recipe...");
        uint256[] memory recipeIds = new uint256[](3);
        recipeIds[0] = 1;
        recipeIds[1] = 2;
        recipeIds[2] = 3;
        uint256[] memory recipeAmounts = new uint256[](3);
        recipeAmounts[0] = 5;
        recipeAmounts[1] = 3;
        recipeAmounts[2] = 1;
        gameEconomy.setRecipe(recipeIds, recipeAmounts);
        console.log("Recipe set successfully");

        // Buy materials
        console.log("Buying materials...");
        gameEconomy.buyMaterial(1, 10); // Wood
        gameEconomy.buyMaterial(2, 5);  // Stone
        gameEconomy.buyMaterial(3, 2);  // Iron
        
        console.log("Wood balance:", gameEconomy.balanceOf(deployer, 1));
        console.log("Stone balance:", gameEconomy.balanceOf(deployer, 2));
        console.log("Iron balance:", gameEconomy.balanceOf(deployer, 3));

        // Craft an item
        console.log("Crafting item...");
        uint256 craftedId = gameEconomy.craft();
        console.log("Crafted item ID:", craftedId);
        console.log("Crafted item balance:", gameEconomy.balanceOf(deployer, craftedId));

        // Check materials were burned
        console.log("Wood balance after craft:", gameEconomy.balanceOf(deployer, 1));
        console.log("Stone balance after craft:", gameEconomy.balanceOf(deployer, 2));
        console.log("Iron balance after craft:", gameEconomy.balanceOf(deployer, 3));

        console.log("\n=== V2 Upgrade ===");
        
        // Deploy V2 implementation
        GameEconomyV2 gameEconomyV2Impl = new GameEconomyV2();
        console.log("V2 Implementation deployed to:", address(gameEconomyV2Impl));
        
        // Upgrade proxy to V2
        gameEconomy.upgradeToAndCall(address(gameEconomyV2Impl), "");
        
        // Cast to V2 interface
        GameEconomyV2 gameEconomyV2 = GameEconomyV2(address(proxy));
        
        // Verify state persisted
        console.log("Currency balance after upgrade:", gameEconomyV2.balanceOf(deployer, 0));
        console.log("Crafted item balance after upgrade:", gameEconomyV2.balanceOf(deployer, craftedId));
        
        // Test V2 new feature - batch purchase
        console.log("Testing V2 batch purchase...");
        
        // Buy more currency first
        gameEconomyV2.buyCurrency{value: 0.1 ether}(100);
        
        // Test batch purchase
        uint256[] memory batchIds = new uint256[](3);
        batchIds[0] = 1; // Wood
        batchIds[1] = 2; // Stone
        batchIds[2] = 3; // Iron
        uint256[] memory batchAmounts = new uint256[](3);
        batchAmounts[0] = 10;
        batchAmounts[1] = 5;
        batchAmounts[2] = 2;
        
        gameEconomyV2.buyMaterialsBatch(batchIds, batchAmounts);
        
        console.log("Wood balance after batch:", gameEconomyV2.balanceOf(deployer, 1));
        console.log("Stone balance after batch:", gameEconomyV2.balanceOf(deployer, 2));
        console.log("Iron balance after batch:", gameEconomyV2.balanceOf(deployer, 3));
        
        // Verify version
        console.log("Contract version:", gameEconomyV2.version());

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("Proxy Address:", address(proxy));
        console.log("V1 Implementation:", address(gameEconomyV1Impl));
        console.log("V2 Implementation:", address(gameEconomyV2Impl));
        console.log("Admin:", deployer);
    }
}