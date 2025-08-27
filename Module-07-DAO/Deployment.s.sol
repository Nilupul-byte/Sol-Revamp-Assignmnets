// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ParticipationToken} from "../src/module-06/ParticipationToken.sol";
import {EarningMechanisms} from "../src/module-06/EarningMechanisms.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {MyGovernor} from "../src/module-06/GovernorContract.sol";
import {GrantContract} from "../src/module-06/GrantContract.sol";

contract DeployDAO is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying contracts with the account:", deployer);
        console.log("Account balance:", deployer.balance);

        // 1. Deploy Participation Token
        ParticipationToken token = new ParticipationToken();
        console.log("Token address:", address(token));

        // 2. Deploy Earning Mechanisms
        EarningMechanisms earningMechanisms = new EarningMechanisms(token);
        console.log("EarningMechanisms address:", address(earningMechanisms));

        // Grant minter role to earning mechanisms
        token.grantRole(token.MINTER_ROLE(), address(earningMechanisms));
        console.log("Granted minter role to earning mechanisms");

        // 3. Deploy Timelock (older version with 3 parameters)
        uint256 minDelay = 2 * 24 * 60 * 60; // 2 days in seconds
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);

        TimelockController timelock = new TimelockController(
            minDelay,
            proposers,
            executors,
            deployer
        );
        console.log("Timelock address:", address(timelock));

        // 4. Deploy Governor - pass the token address directly
        MyGovernor governor = new MyGovernor(
            "DAO Governor", // Name of the governor
            token, // ParticipationToken implementing IVotes
            timelock // TimelockController
        );

        console.log("Governor address:", address(governor));

        // 5. Deploy Grant Contract
        GrantContract grantContract = new GrantContract();
        console.log("GrantContract address:", address(grantContract));

        // Set up roles
        // Grant the governor the PROPOSER_ROLE on the timelock
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        timelock.grantRole(proposerRole, address(governor));
        console.log("Granted proposer role to governor");

        // Grant the governor the EXECUTOR_ROLE on the timelock
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        timelock.grantRole(executorRole, address(governor));
        console.log("Granted executor role to governor");

        // Grant the timelock the GRANT_ADMIN_ROLE on the grant contract
        bytes32 grantAdminRole = grantContract.GRANT_ADMIN_ROLE();
        grantContract.grantRole(grantAdminRole, address(timelock));
        console.log("Granted admin role to timelock");

        // Transfer ownership of contracts to timelock
        earningMechanisms.grantRole(
            earningMechanisms.DEFAULT_ADMIN_ROLE(),
            address(timelock)
        );
        console.log("Transferred earning mechanisms admin to timelock");

        // Transfer token admin to timelock
        token.grantRole(token.DEFAULT_ADMIN_ROLE(), address(timelock));
        token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        console.log("Transferred token admin to timelock");

        vm.stopBroadcast();

        console.log("Deployment completed!");
        console.log("ParticipationToken:", address(token));
        console.log("EarningMechanisms:", address(earningMechanisms));
        console.log("TimelockController:", address(timelock));
        console.log("MyGovernor:", address(governor));
        console.log("GrantContract:", address(grantContract));
    }
}

