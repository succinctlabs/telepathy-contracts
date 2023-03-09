pragma solidity 0.8.16;

import "forge-std/console.sol";
import "forge-std/Test.sol";

import {Message} from "src/amb/interfaces/ITelepathy.sol";
import {MessageEncoding} from "src/libraries/MessageEncoding.sol";

contract MessageEncodingTest is Test {
    uint8 constant DEFAULT_VERSION = 1;
    uint64 constant DEFAULT_NONCE = 123;
    uint32 constant DEFAULT_SOURCE_CHAIN_ID = 5;
    address constant DEFAULT_SOURCE_ADDRESS = address(0xe2B19845Fe2B7Bb353f377d12dD51af012fbba20);
    uint32 constant DEFAULT_DESTINATION_CHAIN_ID = 100;
    bytes32 constant DEFAULT_DESTINATION_ADDRESS = bytes32(uint256(12345678));
    bytes constant DEFAULT_DATA = hex"6789";

    function equals(Message memory a, Message memory b) internal pure returns (bool) {
        return a.version == b.version && a.nonce == b.nonce && a.sourceChainId == b.sourceChainId
            && a.sourceAddress == b.sourceAddress && a.destinationChainId == b.destinationChainId
            && a.destinationAddress == b.destinationAddress && keccak256(a.data) == keccak256(b.data);
    }

    function test_MessageEncoding() public pure {
        Message memory original = Message({
            version: DEFAULT_VERSION,
            nonce: DEFAULT_NONCE,
            sourceChainId: DEFAULT_SOURCE_CHAIN_ID,
            sourceAddress: DEFAULT_SOURCE_ADDRESS,
            destinationChainId: DEFAULT_DESTINATION_CHAIN_ID,
            destinationAddress: DEFAULT_DESTINATION_ADDRESS,
            data: DEFAULT_DATA
        });
        bytes memory msgBytes = MessageEncoding.encode(original);
        Message memory decoded = MessageEncoding.decode(msgBytes);
        require(equals(decoded, original));
    }

    function testFuzz_MessageEncoding_Version(uint8 version) public pure {
        Message memory original = Message({
            version: version,
            nonce: DEFAULT_NONCE,
            sourceChainId: DEFAULT_SOURCE_CHAIN_ID,
            sourceAddress: DEFAULT_SOURCE_ADDRESS,
            destinationChainId: DEFAULT_DESTINATION_CHAIN_ID,
            destinationAddress: DEFAULT_DESTINATION_ADDRESS,
            data: DEFAULT_DATA
        });
        bytes memory msgBytes = MessageEncoding.encode(original);
        Message memory decoded = MessageEncoding.decode(msgBytes);
        require(equals(decoded, original));
    }

    function testFuzz_MessageEncoding_Nonce(uint64 nonce) public pure {
        Message memory original = Message({
            version: DEFAULT_VERSION,
            nonce: nonce,
            sourceChainId: DEFAULT_SOURCE_CHAIN_ID,
            sourceAddress: DEFAULT_SOURCE_ADDRESS,
            destinationChainId: DEFAULT_DESTINATION_CHAIN_ID,
            destinationAddress: DEFAULT_DESTINATION_ADDRESS,
            data: DEFAULT_DATA
        });
        bytes memory msgBytes = MessageEncoding.encode(original);
        Message memory decoded = MessageEncoding.decode(msgBytes);
        require(equals(decoded, original));
    }

    function testFuzz_MessageEncoding_SourceChainId(uint32 sourceChainId) public pure {
        Message memory original = Message({
            version: DEFAULT_VERSION,
            nonce: DEFAULT_NONCE,
            sourceChainId: sourceChainId,
            sourceAddress: DEFAULT_SOURCE_ADDRESS,
            destinationChainId: DEFAULT_DESTINATION_CHAIN_ID,
            destinationAddress: DEFAULT_DESTINATION_ADDRESS,
            data: DEFAULT_DATA
        });
        bytes memory msgBytes = MessageEncoding.encode(original);
        Message memory decoded = MessageEncoding.decode(msgBytes);
        require(equals(decoded, original));
    }

    function testFuzz_MessageEncoding_SourceAddress(address sourceAddress) public pure {
        Message memory original = Message({
            version: DEFAULT_VERSION,
            nonce: DEFAULT_NONCE,
            sourceChainId: DEFAULT_SOURCE_CHAIN_ID,
            sourceAddress: sourceAddress,
            destinationChainId: DEFAULT_DESTINATION_CHAIN_ID,
            destinationAddress: DEFAULT_DESTINATION_ADDRESS,
            data: DEFAULT_DATA
        });
        bytes memory msgBytes = MessageEncoding.encode(original);
        Message memory decoded = MessageEncoding.decode(msgBytes);
        require(equals(decoded, original));
    }

    function testFuzz_MessageEncoding_DestinationChainId(uint32 destinationChainId) public pure {
        Message memory original = Message({
            version: DEFAULT_VERSION,
            nonce: DEFAULT_NONCE,
            sourceChainId: DEFAULT_SOURCE_CHAIN_ID,
            sourceAddress: DEFAULT_SOURCE_ADDRESS,
            destinationChainId: destinationChainId,
            destinationAddress: DEFAULT_DESTINATION_ADDRESS,
            data: DEFAULT_DATA
        });
        bytes memory msgBytes = MessageEncoding.encode(original);
        Message memory decoded = MessageEncoding.decode(msgBytes);
        require(equals(decoded, original));
    }

    function testFuzz_MessageEncoding_DestinationAddress(bytes32 destinationAddress) public pure {
        Message memory original = Message({
            version: DEFAULT_VERSION,
            nonce: DEFAULT_NONCE,
            sourceChainId: DEFAULT_SOURCE_CHAIN_ID,
            sourceAddress: DEFAULT_SOURCE_ADDRESS,
            destinationChainId: DEFAULT_DESTINATION_CHAIN_ID,
            destinationAddress: destinationAddress,
            data: DEFAULT_DATA
        });
        bytes memory msgBytes = MessageEncoding.encode(original);
        Message memory decoded = MessageEncoding.decode(msgBytes);
        require(equals(decoded, original));
    }

    function testFuzz_MessageEncoding_Data(bytes memory data) public pure {
        Message memory original = Message({
            version: DEFAULT_VERSION,
            nonce: DEFAULT_NONCE,
            sourceChainId: DEFAULT_SOURCE_CHAIN_ID,
            sourceAddress: DEFAULT_SOURCE_ADDRESS,
            destinationChainId: DEFAULT_DESTINATION_CHAIN_ID,
            destinationAddress: DEFAULT_DESTINATION_ADDRESS,
            data: data
        });
        bytes memory msgBytes = MessageEncoding.encode(original);
        Message memory decoded = MessageEncoding.decode(msgBytes);
        require(equals(decoded, original));
    }
}
