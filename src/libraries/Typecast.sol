// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.16;

library Address {
    function fromBytes32(bytes32 buffer) internal pure returns (address) {
        return address(uint160(uint256(buffer)));
    }
}

library Bytes32 {
    function fromAddress(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
}
