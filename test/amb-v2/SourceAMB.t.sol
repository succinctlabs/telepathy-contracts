pragma solidity ^0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";
import {WrappedInitialize} from "test/amb-v2/TestUtils.sol";
import {TelepathyRouterV2} from "src/amb-v2/TelepathyRouter.sol";
import {SourceAMBV2} from "src/amb-v2/SourceAMB.sol";
import {UUPSProxy} from "src/libraries/Proxy.sol";
import {Bytes32} from "src/libraries/Typecast.sol";
import {Message} from "src/libraries/Message.sol";
import {VerifierType} from "src/amb-v2/verifier/interfaces/IMessageVerifier.sol";

contract SourceAMBV2Test is Test {
    using Message for bytes;

    event SentMessage(uint64 indexed nonce, bytes32 indexed msgHash, bytes message);

    uint32 constant DEFAULT_DESTINATION_CHAIN_ID = 100;
    address constant DEFAULT_DESTINATION_ADDR = 0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990;
    bytes32 constant DEFAULT_DESTINATION_ADDR_BYTES32 = bytes32("0x690B9A9E9aa1C9dB991C7721a92d35");
    bytes constant DEFAULT_DESTINATION_DATA = hex"deadbeef";
    uint256 constant DEFAULT_FEE = 0.1 ether;

    TelepathyRouterV2 telepathyRouter;

    address bob = payable(makeAddr("bob"));

    function setUp() public {
        TelepathyRouterV2 sourceAMBImplementation = new TelepathyRouterV2();
        UUPSProxy proxy = new UUPSProxy(address(sourceAMBImplementation), "");
        address timelock = makeAddr("timelock");

        telepathyRouter = TelepathyRouterV2(address(proxy));
        (address storageVerifierAddr, address eventVerifierAddr, address attestationVerifierAddr) =
        WrappedInitialize.initializeRouter(
            address(telepathyRouter),
            uint32(block.chainid),
            makeAddr("beaconLightClient"),
            makeAddr("stateQueryGateway"),
            makeAddr("sourceAMB"),
            timelock,
            address(this)
        );

        vm.prank(timelock);
        telepathyRouter.setDefaultVerifier(VerifierType.ZK_STORAGE, storageVerifierAddr);
        vm.prank(timelock);
        telepathyRouter.setDefaultVerifier(VerifierType.ZK_EVENT, eventVerifierAddr);
        vm.prank(timelock);
        telepathyRouter.setDefaultVerifier(
            VerifierType.ATTESTATION_STATE_QUERY, attestationVerifierAddr
        );

        vm.deal(bob, DEFAULT_FEE);
    }

    function test_Send_WhenAddressDestination() public {
        vm.startPrank(bob);
        bytes memory expectedMessage = Message.encode(
            telepathyRouter.VERSION(),
            SourceAMBV2(telepathyRouter).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            Bytes32.fromAddress(DEFAULT_DESTINATION_ADDR),
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageId = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(SourceAMBV2(telepathyRouter).nonce(), expectedMessageId, expectedMessage);

        bytes32 messageId = telepathyRouter.send{value: DEFAULT_FEE}(
            DEFAULT_DESTINATION_CHAIN_ID, DEFAULT_DESTINATION_ADDR, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageId, expectedMessageId);
    }

    function test_Send_WhenBytes32Destination() public {
        vm.startPrank(bob);
        bytes memory expectedMessage = Message.encode(
            telepathyRouter.VERSION(),
            SourceAMBV2(telepathyRouter).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            DEFAULT_DESTINATION_ADDR_BYTES32,
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageId = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(SourceAMBV2(telepathyRouter).nonce(), expectedMessageId, expectedMessage);

        bytes32 messageId = telepathyRouter.send{value: DEFAULT_FEE}(
            DEFAULT_DESTINATION_CHAIN_ID, DEFAULT_DESTINATION_ADDR_BYTES32, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageId, expectedMessageId);
    }

    function test_Send_WhenNoFee() public {
        vm.startPrank(bob);
        bytes memory expectedMessage = Message.encode(
            telepathyRouter.VERSION(),
            SourceAMBV2(telepathyRouter).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            DEFAULT_DESTINATION_ADDR_BYTES32,
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageId = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(SourceAMBV2(telepathyRouter).nonce(), expectedMessageId, expectedMessage);

        bytes32 messageId = telepathyRouter.send(
            DEFAULT_DESTINATION_CHAIN_ID, DEFAULT_DESTINATION_ADDR_BYTES32, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageId, expectedMessageId);
    }

    function testFuzz_Send_MsgSender(address _sender) public {
        vm.deal(_sender, DEFAULT_FEE);
        vm.startPrank(_sender);
        bytes memory expectedMessage = Message.encode(
            telepathyRouter.VERSION(),
            SourceAMBV2(telepathyRouter).nonce(),
            uint32(block.chainid),
            _sender,
            DEFAULT_DESTINATION_CHAIN_ID,
            Bytes32.fromAddress(DEFAULT_DESTINATION_ADDR),
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageId = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(SourceAMBV2(telepathyRouter).nonce(), expectedMessageId, expectedMessage);

        bytes32 messageId = telepathyRouter.send{value: DEFAULT_FEE}(
            DEFAULT_DESTINATION_CHAIN_ID, DEFAULT_DESTINATION_ADDR, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageId, expectedMessageId);
    }

    function testFuzz_Send_DestinationChainId(uint32 _chainId) public {
        vm.assume(_chainId != block.chainid);

        vm.startPrank(bob);
        bytes memory expectedMessage = Message.encode(
            telepathyRouter.VERSION(),
            SourceAMBV2(telepathyRouter).nonce(),
            uint32(block.chainid),
            bob,
            _chainId,
            Bytes32.fromAddress(DEFAULT_DESTINATION_ADDR),
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageId = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(SourceAMBV2(telepathyRouter).nonce(), expectedMessageId, expectedMessage);

        bytes32 messageId = telepathyRouter.send{value: DEFAULT_FEE}(
            _chainId, DEFAULT_DESTINATION_ADDR, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageId, expectedMessageId);
    }

    function testFuzz_Send_DestinationAddress(address _destinationAddress) public {
        vm.startPrank(bob);
        bytes memory expectedMessage = Message.encode(
            telepathyRouter.VERSION(),
            SourceAMBV2(telepathyRouter).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            Bytes32.fromAddress(_destinationAddress),
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageId = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(SourceAMBV2(telepathyRouter).nonce(), expectedMessageId, expectedMessage);

        bytes32 messageId = telepathyRouter.send{value: DEFAULT_FEE}(
            DEFAULT_DESTINATION_CHAIN_ID, _destinationAddress, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageId, expectedMessageId);
    }

    function testFuzz_Send_DestinationBytes32(bytes32 _destinationAddress) public {
        vm.startPrank(bob);
        bytes memory expectedMessage = Message.encode(
            telepathyRouter.VERSION(),
            SourceAMBV2(telepathyRouter).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            _destinationAddress,
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageId = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(SourceAMBV2(telepathyRouter).nonce(), expectedMessageId, expectedMessage);

        bytes32 messageId = telepathyRouter.send{value: DEFAULT_FEE}(
            DEFAULT_DESTINATION_CHAIN_ID, _destinationAddress, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageId, expectedMessageId);
    }

    function testFuzz_Send_Data(bytes calldata _data) public {
        vm.startPrank(bob);
        bytes memory expectedMessage = Message.encode(
            telepathyRouter.VERSION(),
            SourceAMBV2(telepathyRouter).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            Bytes32.fromAddress(DEFAULT_DESTINATION_ADDR),
            _data
        );
        bytes32 expectedMessageId = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(SourceAMBV2(telepathyRouter).nonce(), expectedMessageId, expectedMessage);

        bytes32 messageId = telepathyRouter.send{value: DEFAULT_FEE}(
            DEFAULT_DESTINATION_CHAIN_ID, DEFAULT_DESTINATION_ADDR, _data
        );
        assertEq(messageId, expectedMessageId);
    }

    function testFuzz_Send_Fee(uint256 _fee) public {
        vm.deal(bob, _fee);
        vm.startPrank(bob);
        bytes memory expectedMessage = Message.encode(
            telepathyRouter.VERSION(),
            SourceAMBV2(telepathyRouter).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            Bytes32.fromAddress(DEFAULT_DESTINATION_ADDR),
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageId = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(SourceAMBV2(telepathyRouter).nonce(), expectedMessageId, expectedMessage);

        bytes32 messageId = telepathyRouter.send{value: _fee}(
            DEFAULT_DESTINATION_CHAIN_ID, DEFAULT_DESTINATION_ADDR, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageId, expectedMessageId);
    }
}
