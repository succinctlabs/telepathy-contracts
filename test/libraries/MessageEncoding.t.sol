pragma solidity 0.8.16;

import "forge-std/console.sol";
import "forge-std/Test.sol";

import {Message} from "src/amb/interfaces/ITelepathy.sol";
import {MessageEncoding} from "src/libraries/MessageEncoding.sol";

contract MessageEncodingTest is Test {
    function setUp() public {}

    // TODO add fuzz tests here for the message encoding
    function testMessageEncoding() public view {
        Message memory message = Message({
            version: 1,
            nonce: 123,
            sourceChainId: 5,
            senderAddress: address(0xe2B19845Fe2B7Bb353f377d12dD51af012fbba20),
            recipientChainId: 100,
            recipientAddress: bytes32(uint256(12345678)),
            data: hex"6789"
        });
        bytes memory msgBytes = MessageEncoding.encode(message);
        console.logBytes(msgBytes);
        console.logUint(msgBytes.length);
        Message memory decoded = MessageEncoding.decode(msgBytes);
        require(decoded.version == message.version);
        require(decoded.nonce == message.nonce);
        require(decoded.sourceChainId == message.sourceChainId);
        require(decoded.senderAddress == message.senderAddress);
        require(decoded.recipientChainId == message.recipientChainId);
        require(decoded.recipientAddress == message.recipientAddress);
        require(keccak256(decoded.data) == keccak256(message.data));
    }

    function testMessageEncodingLong() public view {
        console.log("testMessage");
        Message memory message = Message({
            version: 1,
            nonce: 123,
            sourceChainId: 5,
            senderAddress: address(0xe2B19845Fe2B7Bb353f377d12dD51af012fbba20),
            recipientChainId: 100,
            recipientAddress: bytes32(uint256(12345678)),
            data: hex"6789"
        });
        bytes memory msgBytes = abi.encode(message);
        console.logUint(msgBytes.length);
        Message memory decoded = abi.decode(msgBytes, (Message));
        require(decoded.version == message.version);
        require(decoded.nonce == message.nonce);
        require(decoded.sourceChainId == message.sourceChainId);
        require(decoded.senderAddress == message.senderAddress);
        require(decoded.recipientChainId == message.recipientChainId);
        require(decoded.recipientAddress == message.recipientAddress);
        require(keccak256(decoded.data) == keccak256(message.data));
    }
}
