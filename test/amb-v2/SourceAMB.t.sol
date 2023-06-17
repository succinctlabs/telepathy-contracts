pragma solidity ^0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";
import {WrappedInitialize} from "test/amb-v2/TestUtils.sol";
import {TelepathyRouter} from "src/amb-v2/TelepathyRouter.sol";
import {SourceAMB} from "src/amb-v2/SourceAMB.sol";
import {UUPSProxy} from "src/libraries/Proxy.sol";
import {Bytes32} from "src/libraries/Typecast.sol";
import {Message} from "src/libraries/Message.sol";
import {VerifierType} from "src/amb-v2/verifier/interfaces/IMessageVerifier.sol";
import {MerkleProof} from "src/libraries/MerkleProof.sol";

contract SourceAMBTest is Test {
    using Message for bytes;

    event SentMessage(uint64 indexed nonce, bytes32 indexed msgHash, bytes message);

    uint32 constant DEFAULT_DESTINATION_CHAIN_ID = 100;
    address constant DEFAULT_DESTINATION_ADDR = 0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990;
    bytes32 constant DEFAULT_DESTINATION_ADDR_BYTES32 = bytes32("0x690B9A9E9aa1C9dB991C7721a92d35");
    bytes constant DEFAULT_DESTINATION_DATA = hex"deadbeef";

    TelepathyRouter telepathyRouter;

    address bob = payable(makeAddr("bob"));

    function setUp() public {
        TelepathyRouter sourceAMBImplementation = new TelepathyRouter();
        UUPSProxy proxy = new UUPSProxy(address(sourceAMBImplementation), "");
        address timelock = makeAddr("timelock");

        telepathyRouter = TelepathyRouter(address(proxy));
        (address storageVerifierAddr, address eventVerifierAddr, address attestationVerifierAddr) =
        WrappedInitialize.initializeRouter(
            address(telepathyRouter),
            uint32(block.chainid),
            makeAddr("beaconLightClient"),
            makeAddr("ethCallGateway"),
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
            VerifierType.ATTESTATION_ETHCALL, attestationVerifierAddr
        );
    }

    function test_Send_WhenAddressDestination() public {
        vm.startPrank(bob);
        bytes memory expectedMessage = Message.encode(
            telepathyRouter.VERSION(),
            SourceAMB(telepathyRouter).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            Bytes32.fromAddress(DEFAULT_DESTINATION_ADDR),
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageId = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(SourceAMB(telepathyRouter).nonce(), expectedMessageId, expectedMessage);

        bytes32 messageId = telepathyRouter.send(
            DEFAULT_DESTINATION_CHAIN_ID, DEFAULT_DESTINATION_ADDR, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageId, expectedMessageId);
    }

    function test_Send_WhenBytes32Destination() public {
        vm.startPrank(bob);
        bytes memory expectedMessage = Message.encode(
            telepathyRouter.VERSION(),
            SourceAMB(telepathyRouter).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            DEFAULT_DESTINATION_ADDR_BYTES32,
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageId = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(SourceAMB(telepathyRouter).nonce(), expectedMessageId, expectedMessage);

        bytes32 messageId = telepathyRouter.send(
            DEFAULT_DESTINATION_CHAIN_ID, DEFAULT_DESTINATION_ADDR_BYTES32, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageId, expectedMessageId);
    }

    function testFuzz_Send_MsgSender(address sender) public {
        vm.startPrank(sender);
        bytes memory expectedMessage = Message.encode(
            telepathyRouter.VERSION(),
            SourceAMB(telepathyRouter).nonce(),
            uint32(block.chainid),
            sender,
            DEFAULT_DESTINATION_CHAIN_ID,
            Bytes32.fromAddress(DEFAULT_DESTINATION_ADDR),
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageId = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(SourceAMB(telepathyRouter).nonce(), expectedMessageId, expectedMessage);

        bytes32 messageId = telepathyRouter.send(
            DEFAULT_DESTINATION_CHAIN_ID, DEFAULT_DESTINATION_ADDR, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageId, expectedMessageId);
    }

    function testFuzz_Send_DestinationChainId(uint32 _chainId) public {
        vm.assume(_chainId != block.chainid);

        vm.startPrank(bob);
        bytes memory expectedMessage = Message.encode(
            telepathyRouter.VERSION(),
            SourceAMB(telepathyRouter).nonce(),
            uint32(block.chainid),
            bob,
            _chainId,
            Bytes32.fromAddress(DEFAULT_DESTINATION_ADDR),
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageId = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(SourceAMB(telepathyRouter).nonce(), expectedMessageId, expectedMessage);

        bytes32 messageId =
            telepathyRouter.send(_chainId, DEFAULT_DESTINATION_ADDR, DEFAULT_DESTINATION_DATA);
        assertEq(messageId, expectedMessageId);
    }

    function testFuzz_Send_DestinationAddress(address _destinationAddress) public {
        vm.startPrank(bob);
        bytes memory expectedMessage = Message.encode(
            telepathyRouter.VERSION(),
            SourceAMB(telepathyRouter).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            Bytes32.fromAddress(_destinationAddress),
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageId = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(SourceAMB(telepathyRouter).nonce(), expectedMessageId, expectedMessage);

        bytes32 messageId = telepathyRouter.send(
            DEFAULT_DESTINATION_CHAIN_ID, _destinationAddress, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageId, expectedMessageId);
    }

    function testFuzz_Send_DestinationBytes32(bytes32 _destinationAddress) public {
        vm.startPrank(bob);
        bytes memory expectedMessage = Message.encode(
            telepathyRouter.VERSION(),
            SourceAMB(telepathyRouter).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            _destinationAddress,
            DEFAULT_DESTINATION_DATA
        );
        bytes32 expectedMessageId = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(SourceAMB(telepathyRouter).nonce(), expectedMessageId, expectedMessage);

        bytes32 messageId = telepathyRouter.send(
            DEFAULT_DESTINATION_CHAIN_ID, _destinationAddress, DEFAULT_DESTINATION_DATA
        );
        assertEq(messageId, expectedMessageId);
    }

    function testFuzz_Send_Data(bytes calldata _data) public {
        vm.startPrank(bob);
        bytes memory expectedMessage = Message.encode(
            telepathyRouter.VERSION(),
            SourceAMB(telepathyRouter).nonce(),
            uint32(block.chainid),
            bob,
            DEFAULT_DESTINATION_CHAIN_ID,
            Bytes32.fromAddress(DEFAULT_DESTINATION_ADDR),
            _data
        );
        bytes32 expectedMessageId = keccak256(expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit SentMessage(SourceAMB(telepathyRouter).nonce(), expectedMessageId, expectedMessage);

        bytes32 messageId =
            telepathyRouter.send(DEFAULT_DESTINATION_CHAIN_ID, DEFAULT_DESTINATION_ADDR, _data);
        assertEq(messageId, expectedMessageId);
    }

    function test_GetMessageIdRoot() public {
        SourceAMB sourceAMB = SourceAMB(address(telepathyRouter));

        bytes32[] memory ids = new bytes32[](8);
        for (uint256 i = 0; i < 8; i++) {
            ids[i] = sourceAMB.send(0, address(0), abi.encodePacked(i));
        }
        // Do check for nonces = 2
        // uint64[] memory nonces = new uint64[](2);
        // nonces[0] = 0;
        // nonces[1] = 1;
        // bytes32 root = amb.getMessageIdRoot(nonces);
        // bytes32 manualRoot = keccak256(abi.encodePacked(ids[0], ids[1]));
        // assertEq(root, manualRoot);

        uint64[] memory nonces = new uint64[](4);
        nonces[0] = 0;
        nonces[1] = 1;
        nonces[2] = 2;
        nonces[3] = 3;
        bytes32 root = sourceAMB.getMessageIdRoot(nonces);
        // console.log("Layer 0");
        // for (uint256 i = 0; i < 4; i++) {
        //     console.logBytes32(ids[i]);
        // }

        bytes32 left = keccak256(abi.encodePacked(ids[0], ids[1]));
        bytes32 right = keccak256(abi.encodePacked(ids[2], ids[3]));
        // console.log("Layer 1");
        // console.logBytes32(left);
        // console.logBytes32(right);

        bytes32 manualRoot = keccak256(abi.encodePacked(left, right));
        // console.log("Layer 2");
        // console.logBytes32(manualRoot);

        assertEq(root, manualRoot);

        for (uint256 i = 0; i < 4; i++) {
            bytes32[] memory nodes = new bytes32[](nonces.length);
            for (uint256 j = 0; j < nonces.length; j++) {
                nodes[j] = sourceAMB.messages(nonces[j]);
            }

            bytes32[] memory proof = MerkleProof.getProof(nodes, i);
            assertEq(uint64(i), i);
            bool verified = MerkleProof.verifyProof(root, sourceAMB.messages(uint64(i)), proof, i);
            require(verified);
        }
    }
}
