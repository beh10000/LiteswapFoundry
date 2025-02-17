// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Liteswap} from "../src/Liteswap.sol";

contract LiteswapScript is Script {
    
    Liteswap public liteswap;
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        liteswap = new Liteswap();

        vm.stopBroadcast();
    }
}
