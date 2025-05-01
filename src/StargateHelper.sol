// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IStargate.sol";

library StargateHelper {
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function bytes32ToAddress(bytes32 _b32) internal pure returns (address) {
        return address(uint160(uint256(_b32)));
    }

    // Helper to create a Taxi command (immediate bridging)
    function taxiCmd() internal pure returns (bytes memory) {
        return "";  // Empty bytes indicates taxi mode
    }

    // Helper to create a Bus command (batch bridging)
    function busCmd() internal pure returns (bytes memory) {
        return new bytes(1);  // A single byte indicates bus mode
    }

    // Method to create options with compose gas limit
    function composeOptions() internal pure returns (bytes memory) {
        // Format for executor compose option:
        // [type(1)][execute(1)][gasLimit(4)][value(32)]
        
        // Type 0x01 = executor options
        // Instruction 0x02 = lzCompose
        // Gas limit = 200,000 (0x030d40)
        // Value = 0
        
        bytes memory options = new bytes(38);
        options[0] = 0x01; // Type: executor
        options[1] = 0x02; // Instruction: lzCompose
        
        // Gas limit (4 bytes): 200,000 = 0x030d40
        options[2] = 0x00;
        options[3] = 0x03;
        options[4] = 0x0d;
        options[5] = 0x40;
        
        // Value (32 bytes): all zeros by default
        
        return options;
    }
}