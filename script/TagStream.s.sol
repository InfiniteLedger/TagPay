// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/TagStream.sol";

contract TagStreamScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        TagStream tagStream = new TagStream(
            address(0xBD326E3069543a09e66b9f3a0a891c9e6A1eac29)
        );

        vm.stopBroadcast();
    }
}
