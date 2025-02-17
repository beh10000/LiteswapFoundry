// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/Liteswap.sol";
import "../test/TestERC20.sol";

contract DeployLiteswap is Script {
    function run() external {
        // Retrieve private key from environment or use a default one
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Liteswap
        Liteswap liteswap = new Liteswap();
        TestERC20Factory testERC20 = new TestERC20Factory();

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Log the address
        console.log("Liteswap deployed to:", address(liteswap));
        console.log("Factory deployed to:", address(testERC20));
    }
} 