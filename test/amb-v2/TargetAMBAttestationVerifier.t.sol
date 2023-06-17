// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {Address, Bytes32} from "src/libraries/Typecast.sol";
import {MessageStatus} from "src/amb-v2/interfaces/ITelepathy.sol";
import {TelepathyRouter} from "src/amb-v2/TelepathyRouter.sol";
import {SourceAMB} from "src/amb-v2/SourceAMB.sol";
import {UUPSProxy} from "src/libraries/Proxy.sol";
import {WrappedInitialize, SimpleHandler} from "test/amb-v2/TestUtils.sol";
import {Message} from "src/libraries/Message.sol";
import {Bytes32, Address} from "src/libraries/Typecast.sol";
import {VerifierType} from "src/amb-v2/verifier/interfaces/IMessageVerifier.sol";

contract MockEthCallGateway {
    mapping(bytes32 => bytes) store;

    function getAttestedResult(uint32 chainId, address toAddress, bytes memory calldata_)
        external
        returns (bytes memory)
    {
        return store[keccak256(abi.encode(chainId, toAddress, calldata_))];
    }

    function setAttestedResult(
        uint32 chainId,
        address toAddress,
        bytes memory calldata_,
        bytes memory result
    ) external {
        store[keccak256(abi.encode(chainId, toAddress, calldata_))] = result;
    }
}

contract TargetAMBAttestationVerifier is Test {
    using Message for bytes;

    uint32 constant DESTINATION_CHAIN = 10;
    uint32 constant SOURCE_CHAIN = 42161;
    address constant SOURCE_TELEPATHY_ROUTER = 0x41EA857C32c8Cb42EEFa00AF67862eCFf4eB795a;
    address SOURCE_SENDER = makeAddr("sourceMessageSender");
    address DESTINATION_HANDLER = makeAddr("destMessageReceiver");
    bytes constant MESSAGE_DATA = bytes("hello, world!");

    MockEthCallGateway mockEthCallGateway;
    TelepathyRouter telepathyRouter;
    SimpleHandler simpleHandler;

    function setUp() public {
        vm.chainId(DESTINATION_CHAIN);
        mockEthCallGateway = new MockEthCallGateway();

        // Set up the TelepathyRouter contract.
        TelepathyRouter targetAMBImpl = new TelepathyRouter();
        UUPSProxy proxy = new UUPSProxy(address(targetAMBImpl), "");
        telepathyRouter = TelepathyRouter(address(proxy));
        address timelock = makeAddr("timelock");

        (address storageVerifierAddr, address eventVerifierAddr, address attestationVerifierAddr) =
        WrappedInitialize.initializeRouter(
            address(telepathyRouter),
            SOURCE_CHAIN,
            makeAddr("beaconLightClient"),
            address(mockEthCallGateway),
            SOURCE_TELEPATHY_ROUTER,
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

        // Setup the SimpleHandler contract which is a TelepathyHandler,
        // called by the TargetAMB after message execution.
        SimpleHandler simpleHandlerTemplate = new SimpleHandler();
        vm.etch(DESTINATION_HANDLER, address(simpleHandlerTemplate).code);
        simpleHandler = SimpleHandler(DESTINATION_HANDLER);
        simpleHandler.setParams(SOURCE_CHAIN, SOURCE_SENDER, address(telepathyRouter));
        simpleHandler.setVerifierType(VerifierType.ATTESTATION_ETHCALL);
    }

    function test_ExecuteMessageAttestationVerifier() public {
        bytes memory message = Message.encode(
            1,
            0,
            SOURCE_CHAIN,
            SOURCE_SENDER,
            DESTINATION_CHAIN,
            Bytes32.fromAddress(DESTINATION_HANDLER),
            MESSAGE_DATA
        );
        vm.chainId(SOURCE_CHAIN);
        vm.prank(SOURCE_SENDER);
        bytes32 messageId =
            telepathyRouter.send(DESTINATION_CHAIN, DESTINATION_HANDLER, MESSAGE_DATA);
        require(message.getId() == messageId);
        vm.chainId(DESTINATION_CHAIN);
        mockEthCallGateway.setAttestedResult(
            SOURCE_CHAIN,
            SOURCE_TELEPATHY_ROUTER,
            abi.encodeWithSelector(SourceAMB.getMessageId.selector, 0),
            abi.encode(SourceAMB(address(telepathyRouter)).getMessageId(0))
        );

        // Execute the message and check that it succeeded.
        // bytes memory proofData = abi.encode(MESSAGE_PROOF, LIGHT_CLIENT_INDEX, MESSAGE_INDEX);
        bytes memory proofData = hex"";

        telepathyRouter.execute(proofData, message);

        assertTrue(
            telepathyRouter.messageStatus(message.getId()) == MessageStatus.EXECUTION_SUCCEEDED
        );

        // Check that the simpleHandler processed the message correctly.
        assertEq(simpleHandler.nonce(), 1);
        bytes32 expectedDataHash = keccak256(MESSAGE_DATA);
        assertEq(simpleHandler.nonceToDataHash(0), expectedDataHash);

        // Now do a second message with bulk
        bytes memory message2 = Message.encode(
            1,
            1,
            SOURCE_CHAIN,
            SOURCE_SENDER,
            DESTINATION_CHAIN,
            Bytes32.fromAddress(DESTINATION_HANDLER),
            MESSAGE_DATA
        );
        vm.chainId(SOURCE_CHAIN);
        vm.prank(SOURCE_SENDER);
        bytes32 messageId2 =
            telepathyRouter.send(DESTINATION_CHAIN, DESTINATION_HANDLER, MESSAGE_DATA);
        vm.chainId(DESTINATION_CHAIN);
        require(message2.getId() == messageId2);
        uint64[] memory nonces = new uint64[](2);
        nonces[0] = 0;
        nonces[1] = 1;
        mockEthCallGateway.setAttestedResult(
            SOURCE_CHAIN,
            SOURCE_TELEPATHY_ROUTER,
            abi.encodeWithSelector(SourceAMB.getMessageIdRoot.selector, nonces),
            abi.encode(SourceAMB(address(telepathyRouter)).getMessageIdRoot(nonces))
        );

        bytes memory proofDataBatch =
            SourceAMB(address(telepathyRouter)).getProofDataForExecution(nonces, 1);
        uint256 startSmallBatch = gasleft();
        telepathyRouter.execute(proofDataBatch, message2);
        assertTrue(
            telepathyRouter.messageStatus(message2.getId()) == MessageStatus.EXECUTION_SUCCEEDED
        );
        // Check that the simpleHandler processed the message correctly.
        assertEq(simpleHandler.nonce(), 2);
        assertEq(simpleHandler.nonceToDataHash(1), expectedDataHash);

        // ANOTHER TEST WITH LARGE NONCE BATCH
        uint64[] memory largeNonces = new uint64[](8);
        for (uint64 i = 0; i < 8; i++) {
            vm.chainId(SOURCE_CHAIN);
            vm.prank(SOURCE_SENDER);
            telepathyRouter.send(DESTINATION_CHAIN, DESTINATION_HANDLER, MESSAGE_DATA);
            largeNonces[i] = 2 + i;
        }
        vm.chainId(DESTINATION_CHAIN);
        bytes memory message8 = Message.encode(
            1,
            8,
            SOURCE_CHAIN,
            SOURCE_SENDER,
            DESTINATION_CHAIN,
            Bytes32.fromAddress(DESTINATION_HANDLER),
            MESSAGE_DATA
        );
        mockEthCallGateway.setAttestedResult(
            SOURCE_CHAIN,
            SOURCE_TELEPATHY_ROUTER,
            abi.encodeWithSelector(SourceAMB.getMessageIdRoot.selector, largeNonces),
            abi.encode(SourceAMB(address(telepathyRouter)).getMessageIdRoot(largeNonces))
        );
        require(SourceAMB(address(telepathyRouter)).getMessageId(8) == message8.getId());

        bytes memory proofDataBatchLarge =
            SourceAMB(address(telepathyRouter)).getProofDataForExecution(largeNonces, 8);

        uint256 startBatch = gasleft();
        telepathyRouter.execute(proofDataBatchLarge, message8);

        assertTrue(
            telepathyRouter.messageStatus(message8.getId()) == MessageStatus.EXECUTION_SUCCEEDED
        );
        // Check that the simpleHandler processed the message correctly.
        assertEq(simpleHandler.nonce(), 3);
        assertEq(simpleHandler.nonceToDataHash(1), expectedDataHash);

        // Gas profiling at end for singleton so warm vs. cold doesn't matter
        mockEthCallGateway.setAttestedResult(
            SOURCE_CHAIN,
            SOURCE_TELEPATHY_ROUTER,
            abi.encodeWithSelector(SourceAMB.getMessageId.selector, 9),
            abi.encode(SourceAMB(address(telepathyRouter)).getMessageId(9))
        );
        bytes memory message9 = Message.encode(
            1,
            9,
            SOURCE_CHAIN,
            SOURCE_SENDER,
            DESTINATION_CHAIN,
            Bytes32.fromAddress(DESTINATION_HANDLER),
            MESSAGE_DATA
        );
        // Execute the message and check that it succeeded.
        // bytes memory proofData = abi.encode(MESSAGE_PROOF, LIGHT_CLIENT_INDEX, MESSAGE_INDEX);
        bytes memory proofData9 = hex"";

        telepathyRouter.execute(proofData9, message9);
    }
}
