pragma solidity 0.8.16;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import {Message} from "src/libraries/Message.sol";

contract MessageTest is Test {
    using Message for bytes;

    uint8 constant DEFAULT_VERSION = 1;
    uint64 constant DEFAULT_NONCE = 123;
    uint32 constant DEFAULT_SOURCE_CHAIN_ID = 5;
    address constant DEFAULT_SOURCE_ADDRESS = address(0xe2B19845Fe2B7Bb353f377d12dD51af012fbba20);
    uint32 constant DEFAULT_DESTINATION_CHAIN_ID = 100;
    bytes32 constant DEFAULT_DESTINATION_ADDRESS = bytes32(uint256(12345678));
    bytes constant DEFAULT_DATA = hex"6789";

    function test_EncodeMessage() public {
        bytes memory message = Message.encode(
            DEFAULT_VERSION,
            DEFAULT_NONCE,
            DEFAULT_SOURCE_CHAIN_ID,
            DEFAULT_SOURCE_ADDRESS,
            DEFAULT_DESTINATION_CHAIN_ID,
            DEFAULT_DESTINATION_ADDRESS,
            DEFAULT_DATA
        );

        assertEq(message.version(), DEFAULT_VERSION);
        assertEq(message.nonce(), DEFAULT_NONCE);
        assertEq(message.sourceChainId(), DEFAULT_SOURCE_CHAIN_ID);
        assertEq(message.sourceAddress(), DEFAULT_SOURCE_ADDRESS);
        assertEq(message.destinationChainId(), DEFAULT_DESTINATION_CHAIN_ID);
        assertEq(message.destinationAddress(), DEFAULT_DESTINATION_ADDRESS);
        assertEq(keccak256(message.data()), keccak256(DEFAULT_DATA));
    }

    function test_GetId() public {
        bytes memory message = Message.encode(
            DEFAULT_VERSION,
            DEFAULT_NONCE,
            DEFAULT_SOURCE_CHAIN_ID,
            DEFAULT_SOURCE_ADDRESS,
            DEFAULT_DESTINATION_CHAIN_ID,
            DEFAULT_DESTINATION_ADDRESS,
            DEFAULT_DATA
        );
        bytes32 id = message.getId();
        assertEq(id, keccak256(message));
    }

    // Fuzz tests for each of the functions

    function testFuzz_Version(uint8 _version) public {
        bytes memory message = Message.encode(
            _version,
            DEFAULT_NONCE,
            DEFAULT_SOURCE_CHAIN_ID,
            DEFAULT_SOURCE_ADDRESS,
            DEFAULT_DESTINATION_CHAIN_ID,
            DEFAULT_DESTINATION_ADDRESS,
            DEFAULT_DATA
        );
        assertEq(message.version(), _version);
        assertEq(message.nonce(), DEFAULT_NONCE);
        assertEq(message.sourceChainId(), DEFAULT_SOURCE_CHAIN_ID);
        assertEq(message.sourceAddress(), DEFAULT_SOURCE_ADDRESS);
        assertEq(message.destinationChainId(), DEFAULT_DESTINATION_CHAIN_ID);
        assertEq(message.destinationAddress(), DEFAULT_DESTINATION_ADDRESS);
        assertEq(keccak256(message.data()), keccak256(DEFAULT_DATA));
    }

    function testFuzz_Nonce(uint64 _nonce) public {
        bytes memory message = Message.encode(
            DEFAULT_VERSION,
            _nonce,
            DEFAULT_SOURCE_CHAIN_ID,
            DEFAULT_SOURCE_ADDRESS,
            DEFAULT_DESTINATION_CHAIN_ID,
            DEFAULT_DESTINATION_ADDRESS,
            DEFAULT_DATA
        );
        assertEq(message.version(), DEFAULT_VERSION);
        assertEq(message.nonce(), _nonce);
        assertEq(message.sourceChainId(), DEFAULT_SOURCE_CHAIN_ID);
        assertEq(message.sourceAddress(), DEFAULT_SOURCE_ADDRESS);
        assertEq(message.destinationChainId(), DEFAULT_DESTINATION_CHAIN_ID);
        assertEq(message.destinationAddress(), DEFAULT_DESTINATION_ADDRESS);
        assertEq(keccak256(message.data()), keccak256(DEFAULT_DATA));
    }

    function testFuzz_SourceChainId(uint32 _sourceChainId) public {
        bytes memory message = Message.encode(
            DEFAULT_VERSION,
            DEFAULT_NONCE,
            _sourceChainId,
            DEFAULT_SOURCE_ADDRESS,
            DEFAULT_DESTINATION_CHAIN_ID,
            DEFAULT_DESTINATION_ADDRESS,
            DEFAULT_DATA
        );
        assertEq(message.version(), DEFAULT_VERSION);
        assertEq(message.nonce(), DEFAULT_NONCE);
        assertEq(message.sourceChainId(), _sourceChainId);
        assertEq(message.sourceAddress(), DEFAULT_SOURCE_ADDRESS);
        assertEq(message.destinationChainId(), DEFAULT_DESTINATION_CHAIN_ID);
        assertEq(message.destinationAddress(), DEFAULT_DESTINATION_ADDRESS);
        assertEq(keccak256(message.data()), keccak256(DEFAULT_DATA));
    }

    function testFuzz_SourceAddress(address _sourceAddress) public {
        bytes memory message = Message.encode(
            DEFAULT_VERSION,
            DEFAULT_NONCE,
            DEFAULT_SOURCE_CHAIN_ID,
            _sourceAddress,
            DEFAULT_DESTINATION_CHAIN_ID,
            DEFAULT_DESTINATION_ADDRESS,
            DEFAULT_DATA
        );
        assertEq(message.version(), DEFAULT_VERSION);
        assertEq(message.nonce(), DEFAULT_NONCE);
        assertEq(message.sourceChainId(), DEFAULT_SOURCE_CHAIN_ID);
        assertEq(message.sourceAddress(), _sourceAddress);
        assertEq(message.destinationChainId(), DEFAULT_DESTINATION_CHAIN_ID);
        assertEq(message.destinationAddress(), DEFAULT_DESTINATION_ADDRESS);
        assertEq(keccak256(message.data()), keccak256(DEFAULT_DATA));
    }

    function testFuzz_destinationChainId(uint32 _destinationChainId) public {
        bytes memory message = Message.encode(
            DEFAULT_VERSION,
            DEFAULT_NONCE,
            DEFAULT_SOURCE_CHAIN_ID,
            DEFAULT_SOURCE_ADDRESS,
            _destinationChainId,
            DEFAULT_DESTINATION_ADDRESS,
            DEFAULT_DATA
        );
        assertEq(message.version(), DEFAULT_VERSION);
        assertEq(message.nonce(), DEFAULT_NONCE);
        assertEq(message.sourceChainId(), DEFAULT_SOURCE_CHAIN_ID);
        assertEq(message.sourceAddress(), DEFAULT_SOURCE_ADDRESS);
        assertEq(message.destinationChainId(), _destinationChainId);
        assertEq(message.destinationAddress(), DEFAULT_DESTINATION_ADDRESS);
        assertEq(keccak256(message.data()), keccak256(DEFAULT_DATA));
    }

    function testFuzz_DestinationAddress(bytes32 destinationAddress) public {
        bytes memory message = Message.encode(
            DEFAULT_VERSION,
            DEFAULT_NONCE,
            DEFAULT_SOURCE_CHAIN_ID,
            DEFAULT_SOURCE_ADDRESS,
            DEFAULT_DESTINATION_CHAIN_ID,
            destinationAddress,
            DEFAULT_DATA
        );
        assertEq(message.version(), DEFAULT_VERSION);
        assertEq(message.nonce(), DEFAULT_NONCE);
        assertEq(message.sourceChainId(), DEFAULT_SOURCE_CHAIN_ID);
        assertEq(message.sourceAddress(), DEFAULT_SOURCE_ADDRESS);
        assertEq(message.destinationChainId(), DEFAULT_DESTINATION_CHAIN_ID);
        assertEq(message.destinationAddress(), destinationAddress);
        assertEq(keccak256(message.data()), keccak256(DEFAULT_DATA));
    }

    function testFuzz_Data(bytes memory _data) public {
        vm.assume(_data.length > 0);
        bytes memory message = Message.encode(
            DEFAULT_VERSION,
            DEFAULT_NONCE,
            DEFAULT_SOURCE_CHAIN_ID,
            DEFAULT_SOURCE_ADDRESS,
            DEFAULT_DESTINATION_CHAIN_ID,
            DEFAULT_DESTINATION_ADDRESS,
            _data
        );
        assertEq(message.version(), DEFAULT_VERSION);
        assertEq(message.nonce(), DEFAULT_NONCE);
        assertEq(message.sourceChainId(), DEFAULT_SOURCE_CHAIN_ID);
        assertEq(message.sourceAddress(), DEFAULT_SOURCE_ADDRESS);
        assertEq(message.destinationChainId(), DEFAULT_DESTINATION_CHAIN_ID);
        assertEq(message.destinationAddress(), DEFAULT_DESTINATION_ADDRESS);
        assertEq(keccak256(message.data()), keccak256(_data));
    }
}
