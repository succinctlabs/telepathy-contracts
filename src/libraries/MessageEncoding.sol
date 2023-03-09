pragma solidity 0.8.16;

import {Message} from "src/amb/interfaces/ITelepathy.sol";

// From here: https://stackoverflow.com/questions/74443594/how-to-slice-bytes-memory-in-solidity
library BytesLib {
    function slice(bytes memory _bytes, uint256 _start, uint256 _length)
        internal
        pure
        returns (bytes memory)
    {
        require(_length + 31 >= _length, "slice_overflow");
        require(_bytes.length >= _start + _length, "slice_outOfBounds");

        bytes memory tempBytes;

        // Check length is 0. `iszero` return 1 for `true` and 0 for `false`.
        assembly {
            switch iszero(_length)
            case 0 {
                // Get a location of some free memory and store it in tempBytes as
                // Solidity does for memory variables.
                tempBytes := mload(0x40)

                // Calculate length mod 32 to handle slices that are not a multiple of 32 in size.
                let lengthmod := and(_length, 31)

                // tempBytes will have the following format in memory: <length><data>
                // When copying data we will offset the start forward to avoid allocating additional memory
                // Therefore part of the length area will be written, but this will be overwritten later anyways.
                // In case no offset is require, the start is set to the data region (0x20 from the tempBytes)
                // mc will be used to keep track where to copy the data to.
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                    // Same logic as for mc is applied and additionally the start offset specified for the method is added
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    // increase `mc` and `cc` to read the next word from memory
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    // Copy the data from source (cc location) to the slice data (mc location)
                    mstore(mc, mload(cc))
                }

                // Store the length of the slice. This will overwrite any partial data that
                // was copied when having slices that are not a multiple of 32.
                mstore(tempBytes, _length)

                // update free-memory pointer
                // allocating the array padded to 32 bytes like the compiler does now
                // To set the used memory as a multiple of 32, add 31 to the actual memory usage (mc)
                // and remove the modulo 32 (the `and` with `not(31)`)
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            // if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)
                // zero out the 32 bytes slice we are about to return
                // we need to do it because Solidity does not garbage collect
                mstore(tempBytes, 0)

                // update free-memory pointer
                // tempBytes uses 32 bytes in memory (even when empty) for the length.
                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }
}

library MessageEncoding {
    function encode(Message memory message) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            message.version,
            message.nonce,
            message.sourceChainId,
            message.sourceAddress,
            message.destinationChainId,
            message.destinationAddress,
            message.data
        );
    }

    function encode(
        uint8 version,
        uint64 nonce,
        uint32 sourceChainId,
        address sourceAddress,
        uint32 destinationChainId,
        bytes32 destinationAddress,
        bytes memory data
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            version,
            nonce,
            sourceChainId,
            sourceAddress,
            destinationChainId,
            destinationAddress,
            data
        );
    }

    function decode(bytes memory data) internal pure returns (Message memory message) {
        uint8 version;
        uint64 nonce; // 64 / 8 = 8
        uint32 sourceChainId; // 32 / 8 = 4
        address sourceAddress; // 20 bytes
        uint32 destinationChainId; // 4 bytes
        bytes32 destinationAddress; // 32
        // 8 + 4 + 20 + 4 + 32 = 68
        assembly {
            version := mload(add(data, 1))

            nonce := mload(add(data, 9))

            sourceChainId := mload(add(data, 13))

            sourceAddress := mload(add(data, 33))

            destinationChainId := mload(add(data, 37))

            destinationAddress := mload(add(data, 69))
        }
        message.version = version;
        message.nonce = nonce;
        message.sourceChainId = sourceChainId;
        message.sourceAddress = sourceAddress;
        message.destinationChainId = destinationChainId;
        message.destinationAddress = destinationAddress;
        message.data = BytesLib.slice(data, 69, data.length - 69);
    }
}
