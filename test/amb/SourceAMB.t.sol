pragma solidity 0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";
import {WrappedInitialize} from "./TargetAMB.t.sol";
import {TelepathyRouter} from "src/amb/TelepathyRouter.sol";
import {SourceAMB} from "src/amb/SourceAMB.sol";
import {UUPSProxy} from "src/libraries/Proxy.sol";
import {Bytes32} from "src/libraries/Typecast.sol";
import {MessageEncoding} from "src/libraries/MessageEncoding.sol";

contract SourceAMBTest is Test {
    event SentMessage(uint64 indexed nonce, bytes32 indexed msgHash, bytes message);

    uint32 constant DEFAULT_DESTINATION_CHAIN_ID = 100;
    address constant DEFAULT_DESTINATION_ADDR = 0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990;
    bytes32 constant DEFAULT_DESTINATION_ADDR_BYTES32 = bytes32("0x690B9A9E9aa1C9dB991C7721a92d35");
    bytes constant DEFAULT_DESTINATION_DATA = hex"deadbeef";

    TelepathyRouter wrappedSourceAMBProxy;

    address bob = payable(makeAddr("bob"));

    function setUp() public {
        TelepathyRouter sourceAMBImplementation = new TelepathyRouter();
        UUPSProxy proxy = new UUPSProxy(address(sourceAMBImplementation), "");

        wrappedSourceAMBProxy = TelepathyRouter(address(proxy));
        WrappedInitialize.init(
            address(wrappedSourceAMBProxy),
            uint32(block.chainid),
            makeAddr("lightclient"),
            makeAddr("sourceAMB"),
            address(this),
            address(this)
        );
    }

    function test_Send_WhenAddressDestination() public {
        vm.startPrank(bob);
        bytes memory expectedMessage = MessageEncoding.encode(
            wrappedSourceAMBProxy.VERSION(),
            SourceAMB(wrappedSourceAMBProxy).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            Bytes32.fromAddress(DEFAULT_DESTINATION_ADDR),
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageRoot = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(
            SourceAMB(wrappedSourceAMBProxy).nonce(), expectedMessageRoot, expectedMessage
        );

        bytes32 messageRoot = wrappedSourceAMBProxy.send(
            DEFAULT_DESTINATION_CHAIN_ID, DEFAULT_DESTINATION_ADDR, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageRoot, expectedMessageRoot);
    }

    function test_Send_WhenBytes32Destination() public {
        vm.startPrank(bob);
        bytes memory expectedMessage = MessageEncoding.encode(
            wrappedSourceAMBProxy.VERSION(),
            SourceAMB(wrappedSourceAMBProxy).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            DEFAULT_DESTINATION_ADDR_BYTES32,
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageRoot = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(
            SourceAMB(wrappedSourceAMBProxy).nonce(), expectedMessageRoot, expectedMessage
        );

        bytes32 messageRoot = wrappedSourceAMBProxy.send(
            DEFAULT_DESTINATION_CHAIN_ID, DEFAULT_DESTINATION_ADDR_BYTES32, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageRoot, expectedMessageRoot);
    }

    function test_SendViaStorage_WhenAddressDestination() public {
        vm.startPrank(bob);
        bytes memory expectedMessage = MessageEncoding.encode(
            wrappedSourceAMBProxy.VERSION(),
            SourceAMB(wrappedSourceAMBProxy).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            Bytes32.fromAddress(DEFAULT_DESTINATION_ADDR),
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageRoot = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(
            SourceAMB(wrappedSourceAMBProxy).nonce(), expectedMessageRoot, expectedMessage
        );

        bytes32 messageRoot = wrappedSourceAMBProxy.sendViaStorage(
            DEFAULT_DESTINATION_CHAIN_ID, DEFAULT_DESTINATION_ADDR, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageRoot, expectedMessageRoot);
        assertEq(
            wrappedSourceAMBProxy.messages(SourceAMB(wrappedSourceAMBProxy).nonce() - 1),
            expectedMessageRoot
        );
    }

    function test_SendViaStorage_WhenBytes32Destination() public {
        vm.startPrank(bob);
        bytes memory expectedMessage = MessageEncoding.encode(
            wrappedSourceAMBProxy.VERSION(),
            SourceAMB(wrappedSourceAMBProxy).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            DEFAULT_DESTINATION_ADDR_BYTES32,
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageRoot = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(
            SourceAMB(wrappedSourceAMBProxy).nonce(), expectedMessageRoot, expectedMessage
        );

        bytes32 messageRoot = wrappedSourceAMBProxy.sendViaStorage(
            DEFAULT_DESTINATION_CHAIN_ID, DEFAULT_DESTINATION_ADDR_BYTES32, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageRoot, expectedMessageRoot);
        assertEq(
            wrappedSourceAMBProxy.messages(SourceAMB(wrappedSourceAMBProxy).nonce() - 1),
            expectedMessageRoot
        );
    }

    function testFuzz_Send_MsgSender(address sender) public {
        vm.startPrank(sender);
        bytes memory expectedMessage = MessageEncoding.encode(
            wrappedSourceAMBProxy.VERSION(),
            SourceAMB(wrappedSourceAMBProxy).nonce(),
            uint32(block.chainid),
            sender,
            DEFAULT_DESTINATION_CHAIN_ID,
            Bytes32.fromAddress(DEFAULT_DESTINATION_ADDR),
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageRoot = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(
            SourceAMB(wrappedSourceAMBProxy).nonce(), expectedMessageRoot, expectedMessage
        );

        bytes32 messageRoot = wrappedSourceAMBProxy.send(
            DEFAULT_DESTINATION_CHAIN_ID, DEFAULT_DESTINATION_ADDR, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageRoot, expectedMessageRoot);
    }

    function testFuzz_Send_DestinationChainId(uint32 _chainId) public {
        vm.assume(_chainId != block.chainid);

        vm.startPrank(bob);
        bytes memory expectedMessage = MessageEncoding.encode(
            wrappedSourceAMBProxy.VERSION(),
            SourceAMB(wrappedSourceAMBProxy).nonce(),
            uint32(block.chainid),
            bob,
            _chainId,
            Bytes32.fromAddress(DEFAULT_DESTINATION_ADDR),
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageRoot = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(
            SourceAMB(wrappedSourceAMBProxy).nonce(), expectedMessageRoot, expectedMessage
        );

        bytes32 messageRoot =
            wrappedSourceAMBProxy.send(_chainId, DEFAULT_DESTINATION_ADDR, DEFAULT_DESTINATION_DATA);
        assertEq(messageRoot, expectedMessageRoot);
    }

    function testFuzz_Send_DestinationAddress(address _destinationAddress) public {
        vm.startPrank(bob);
        bytes memory expectedMessage = MessageEncoding.encode(
            wrappedSourceAMBProxy.VERSION(),
            SourceAMB(wrappedSourceAMBProxy).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            Bytes32.fromAddress(_destinationAddress),
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageRoot = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(
            SourceAMB(wrappedSourceAMBProxy).nonce(), expectedMessageRoot, expectedMessage
        );

        bytes32 messageRoot = wrappedSourceAMBProxy.send(
            DEFAULT_DESTINATION_CHAIN_ID, _destinationAddress, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageRoot, expectedMessageRoot);
    }

    function testFuzz_Send_DestinationBytes32(bytes32 _destinationAddress) public {
        vm.startPrank(bob);
        bytes memory expectedMessage = MessageEncoding.encode(
            wrappedSourceAMBProxy.VERSION(),
            SourceAMB(wrappedSourceAMBProxy).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            _destinationAddress,
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageRoot = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(
            SourceAMB(wrappedSourceAMBProxy).nonce(), expectedMessageRoot, expectedMessage
        );

        bytes32 messageRoot = wrappedSourceAMBProxy.send(
            DEFAULT_DESTINATION_CHAIN_ID, _destinationAddress, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageRoot, expectedMessageRoot);
    }

    function testFuzz_Send_Data(bytes calldata _data) public {
        vm.startPrank(bob);
        bytes memory expectedMessage = MessageEncoding.encode(
            wrappedSourceAMBProxy.VERSION(),
            SourceAMB(wrappedSourceAMBProxy).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            Bytes32.fromAddress(DEFAULT_DESTINATION_ADDR),
            _data
        );
        bytes32 expectedMessageRoot = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(
            SourceAMB(wrappedSourceAMBProxy).nonce(), expectedMessageRoot, expectedMessage
        );

        bytes32 messageRoot = wrappedSourceAMBProxy.send(
            DEFAULT_DESTINATION_CHAIN_ID, DEFAULT_DESTINATION_ADDR, _data
        );
        assertEq(messageRoot, expectedMessageRoot);
    }
}
