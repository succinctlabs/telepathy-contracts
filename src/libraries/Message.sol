// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

/// @title Message
/// @author Succinct Labs
/// @notice This library is used to encode and decode message data.
library Message {
    /// @dev Since bytes are a dynamic type, they have the first 32 bytes reserved for the
    ///      length of the data, so we start at an offset of 32.
    uint256 private constant VERSION_OFFSET = 32;
    uint256 private constant NONCE_OFFSET = 33;
    uint256 private constant SOURCE_CHAIN_ID_OFFSET = 41;
    uint256 private constant SOURCE_ADDRESS_OFFSET = 45;
    uint256 private constant DESTINATION_CHAIN_ID_OFFSET = 65;
    uint256 private constant DESTINATION_ADDRESS_OFFSET = 69;

    /// @notice Encodes the message into a single bytes array.
    /// @param _version The version of the message.
    /// @param _nonce The nonce of the message.
    /// @param _sourceChainId The source chain ID of the message.
    /// @param _sourceAddress The source address of the message.
    /// @param _destinationChainId The destination chain ID of the message.
    /// @param _destinationAddress The destination address of the message.
    /// @param _data The raw content of the message.
    function encode(
        uint8 _version,
        uint64 _nonce,
        uint32 _sourceChainId,
        address _sourceAddress,
        uint32 _destinationChainId,
        bytes32 _destinationAddress,
        bytes memory _data
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            _version,
            _nonce,
            _sourceChainId,
            _sourceAddress,
            _destinationChainId,
            _destinationAddress,
            _data
        );
    }

    function getId(bytes memory _message) internal pure returns (bytes32) {
        return keccak256(_message);
    }

    function version(bytes memory _message) internal pure returns (uint8 version_) {
        assembly {
            // 256 - 248 = 8 bits to extract.
            version_ := shr(248, mload(add(_message, VERSION_OFFSET)))
        }
        return version_;
    }

    function nonce(bytes memory _message) internal pure returns (uint64 nonce_) {
        assembly {
            // 256 - 192 = 64 bits to extract.
            nonce_ := shr(192, mload(add(_message, NONCE_OFFSET)))
        }
        return nonce_;
    }

    function sourceChainId(bytes memory _message) internal pure returns (uint32 sourceChainId_) {
        assembly {
            // 256 - 224 = 32 bits to extract.
            sourceChainId_ := shr(224, mload(add(_message, SOURCE_CHAIN_ID_OFFSET)))
        }
        return sourceChainId_;
    }

    function sourceAddress(bytes memory _message) internal pure returns (address sourceAddress_) {
        assembly {
            // 256 - 96 = 160 bits to extract.
            sourceAddress_ := shr(96, mload(add(_message, SOURCE_ADDRESS_OFFSET)))
        }
        return sourceAddress_;
    }

    function destinationChainId(bytes memory _message)
        internal
        pure
        returns (uint32 destinationChainId_)
    {
        assembly {
            // 256 - 224 = 32 bits to extract.
            destinationChainId_ := shr(224, mload(add(_message, DESTINATION_CHAIN_ID_OFFSET)))
        }
        return destinationChainId_;
    }

    function destinationAddress(bytes memory _message)
        internal
        pure
        returns (address destinationAddress_)
    {
        assembly {
            // Extract the full 256 bits in the slot.
            // Even though the destination address is stored as a bytes32, we want to read it as an address.
            // This is equivalent to address(uint160(destinationAddress_)) if we load destinationAddress_ as a full bytes32.
            destinationAddress_ := mload(add(_message, DESTINATION_ADDRESS_OFFSET))
        }
        return destinationAddress_;
    }

    function data(bytes memory _message) internal pure returns (bytes memory data_) {
        // All bytes after the destination address is the data.
        data_ = BytesLib.slice(
            _message, DESTINATION_ADDRESS_OFFSET, _message.length - DESTINATION_ADDRESS_OFFSET
        );
    }
}

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
