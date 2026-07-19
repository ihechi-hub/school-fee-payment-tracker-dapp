// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/FeesTracker.sol";

contract DeployFeesTracker is Script {
    function run() external {
        // Start broadcast - will use the private key from command line
        vm.startBroadcast();
        
        // Deploy the contract
        FeeTracker feeTracker = new FeeTracker();
        
        // Log without emojis
        console.log("FeeTracker deployed to:", address(feeTracker));
        console.log("Owner:", feeTracker.owner());
        
        vm.stopBroadcast();
    }
}