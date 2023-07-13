pragma solidity ^0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {MessageStatus, ITelepathyHandlerV2} from "src/amb-v2/interfaces/ITelepathy.sol";
import {TelepathyRouterV2} from "src/amb-v2/TelepathyRouter.sol";
import {Message} from "src/libraries/Message.sol";
import {UUPSProxy} from "src/libraries/Proxy.sol";
import {LightClientMock} from "src/lightclient/LightClientMock.sol";
import {WrappedInitialize, SimpleHandler} from "test/amb-v2/TestUtils.sol";
import {TelepathyStorageVerifier} from "src/amb-v2/verifier/TelepathyStorageVerifier.sol";
import {VerifierType} from "src/amb-v2/verifier/interfaces/IMessageVerifier.sol";

// The weird ordering here is because vm.parseJSON requires
// alphabetaical ordering of the fields in the struct
struct ExecuteMessageFromStorageFixture {
    uint32 DEST_CHAIN;
    uint32 SOURCE_CHAIN;
    string[] accountProof;
    uint64 blockNumber;
    bytes message;
    address sourceAMBAddress;
    address sourceMessageSender;
    bytes32 stateRoot;
    string[] storageProof;
    bytes32 storageRoot;
}

struct ExecuteMessageFromStorageParams {
    uint32 DEST_CHAIN;
    uint32 SOURCE_CHAIN;
    bytes[] accountProof;
    uint64 blockNumber;
    bytes message;
    address sourceAMBAddress;
    address sourceMessageSender;
    bytes32 stateRoot;
    bytes[] storageProof;
    bytes32 storageRoot;
}

contract TestErrors {
    error MessageAlreadyExecuted(bytes32 messageId);
    error MessageNotForChain(bytes32 messageId, uint32 destinationChainId, uint32 currentChainId);
    error MessageWrongVersion(bytes32 messageId, uint8 messageVersion, uint8 currentVersion);
    error ExecutionDisabled();
    error VerifierNotFound(uint256 verifierType);
    error VerificationFailed();
    error CallFailed();
    error InvalidSelector();
}

contract TargetAMBV2StorageVerifierTest is Test, TestErrors {
    using Message for bytes;

    LightClientMock beaconLightClient;
    TelepathyRouterV2 telepathyRouter;
    SimpleHandler simpleHandler;
    TelepathyStorageVerifier storageVerifier;
    address timelock;
    address guardian;
    address zkRelayer;

    function setUp() public {
        beaconLightClient = new LightClientMock();
    }

    function parseParams(string memory filename)
        internal
        view
        returns (ExecuteMessageFromStorageParams memory)
    {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/amb-v2/fixtures/", filename, ".json");
        string memory file = vm.readFile(path);
        bytes memory parsed = vm.parseJson(file);
        ExecuteMessageFromStorageFixture memory fixture =
            abi.decode(parsed, (ExecuteMessageFromStorageFixture));

        ExecuteMessageFromStorageParams memory params;
        params.DEST_CHAIN = fixture.DEST_CHAIN;
        params.SOURCE_CHAIN = fixture.SOURCE_CHAIN;
        params.accountProof = buildAccountProof(fixture);
        params.blockNumber = fixture.blockNumber;
        params.message = fixture.message;
        params.sourceAMBAddress = fixture.sourceAMBAddress;
        params.sourceMessageSender = fixture.sourceMessageSender;
        params.stateRoot = fixture.stateRoot;
        params.storageProof = buildStorageProof(fixture);
        params.storageRoot = fixture.storageRoot;

        return params;
    }

    function buildAccountProof(ExecuteMessageFromStorageFixture memory fixture)
        internal
        pure
        returns (bytes[] memory)
    {
        bytes[] memory proof = new bytes[](8);
        proof[0] = vm.parseBytes(fixture.accountProof[0]);
        proof[1] = vm.parseBytes(fixture.accountProof[1]);
        proof[2] = vm.parseBytes(fixture.accountProof[2]);
        proof[3] = vm.parseBytes(fixture.accountProof[3]);
        proof[4] = vm.parseBytes(fixture.accountProof[4]);
        proof[5] = vm.parseBytes(fixture.accountProof[5]);
        proof[6] = vm.parseBytes(fixture.accountProof[6]);
        proof[7] = vm.parseBytes(fixture.accountProof[7]);
        return proof;
    }

    function buildStorageProof(ExecuteMessageFromStorageFixture memory fixture)
        internal
        pure
        returns (bytes[] memory)
    {
        bytes[] memory proof = new bytes[](3);
        proof[0] = vm.parseBytes(fixture.storageProof[0]);
        proof[1] = vm.parseBytes(fixture.storageProof[1]);
        proof[2] = vm.parseBytes(fixture.storageProof[2]);
        return proof;
    }

    function getDefaultContractSetup(ExecuteMessageFromStorageParams memory messageParams)
        internal
    {
        vm.chainId(messageParams.DEST_CHAIN);

        // Set up the TelepathyRouterV2 contract
        TelepathyRouterV2 targetAMBImpl = new TelepathyRouterV2();
        UUPSProxy proxy = new UUPSProxy(address(targetAMBImpl), "");
        telepathyRouter = TelepathyRouterV2(address(proxy));
        timelock = makeAddr("timelock");
        guardian = makeAddr("guardian");

        (address storageVerifierAddr, address eventVerifierAddr, address attestationVerifierAddr) =
        WrappedInitialize.initializeRouter(
            address(telepathyRouter),
            messageParams.SOURCE_CHAIN,
            address(beaconLightClient),
            makeAddr("stateQueryGateway"),
            messageParams.sourceAMBAddress,
            timelock,
            guardian
        );
        // manually override VERSION, TODO generate new fixtures for V2
        vm.store(address(telepathyRouter), bytes32(uint256(8)), bytes32(uint256(uint8(1))));

        vm.prank(timelock);
        telepathyRouter.setDefaultVerifier(VerifierType.ZK_STORAGE, storageVerifierAddr);
        vm.prank(timelock);
        telepathyRouter.setDefaultVerifier(VerifierType.ZK_EVENT, eventVerifierAddr);
        vm.prank(timelock);
        telepathyRouter.setDefaultVerifier(
            VerifierType.ATTESTATION_STATE_QUERY, attestationVerifierAddr
        );

        storageVerifier = TelepathyStorageVerifier(storageVerifierAddr);

        // Add zkRelayer to whitelist
        zkRelayer = makeAddr("zkRelayer");
        vm.prank(guardian);
        telepathyRouter.setZkRelayer(zkRelayer, true);

        // Then initialize the contract that will be called by the TargetAMBV2
        SimpleHandler simpleHandlerTemplate = new SimpleHandler();
        vm.etch(address(0), address(simpleHandlerTemplate).code);
        simpleHandler = SimpleHandler(address(0));
        simpleHandler.setParams(
            messageParams.SOURCE_CHAIN, messageParams.sourceMessageSender, address(telepathyRouter)
        );
        simpleHandler.setVerifierType(VerifierType.ZK_STORAGE);

        // Then set the execution root in the MockLightClient
        // Typically we should use the slot here, but we just use the block number since it doesn't
        // matter in the MockLightClient
        beaconLightClient.setExecutionRoot(messageParams.blockNumber, messageParams.stateRoot);
    }

    function test_ExecuteMessage() public {
        // This test is generated using `cli/src/generateTest.ts`
        ExecuteMessageFromStorageParams memory messageParams = parseParams("storage1");
        getDefaultContractSetup(messageParams);

        // Finally, execute the message and check that it succeeded
        vm.prank(zkRelayer);
        telepathyRouter.execute(
            abi.encode(
                messageParams.blockNumber, messageParams.accountProof, messageParams.storageProof
            ),
            messageParams.message
        );
        assertTrue(
            telepathyRouter.messageStatus(messageParams.message.getId())
                == MessageStatus.EXECUTION_SUCCEEDED
        );

        // Check that the simpleHandler processed the message correctly
        assertEq(simpleHandler.nonce(), 1);
        bytes32 expectedDataHash = keccak256(abi.encode(address(0), uint256(100)));
        assertEq(simpleHandler.nonceToDataHash(0), expectedDataHash);
    }

    function test_ExecuteMessage_WrongSourceAddressFails() public {
        ExecuteMessageFromStorageParams memory messageParams = parseParams("storage1");
        messageParams.sourceMessageSender = address(0x1234); // Set the source address to something random
        getDefaultContractSetup(messageParams);

        // Finally, execute the message and check that it failed
        vm.expectRevert();
        vm.prank(zkRelayer);
        telepathyRouter.execute(
            abi.encode(
                messageParams.blockNumber, messageParams.accountProof, messageParams.storageProof
            ),
            messageParams.message
        );
        assertFalse(
            telepathyRouter.messageStatus(messageParams.message.getId())
                == MessageStatus.EXECUTION_SUCCEEDED
        );

        assertEq(simpleHandler.nonce(), 0);
    }

    function test_RevertExecuteMessage_WhenDuplicate() public {
        // Tests that a message can only be executed once.
        ExecuteMessageFromStorageParams memory messageParams = parseParams("storage1");
        getDefaultContractSetup(messageParams);

        vm.prank(zkRelayer);
        telepathyRouter.execute(
            abi.encode(
                messageParams.blockNumber, messageParams.accountProof, messageParams.storageProof
            ),
            messageParams.message
        );
        assertTrue(
            telepathyRouter.messageStatus(messageParams.message.getId())
                == MessageStatus.EXECUTION_SUCCEEDED
        );

        vm.expectRevert(
            abi.encodeWithSelector(MessageAlreadyExecuted.selector, messageParams.message.getId())
        );
        vm.prank(zkRelayer);
        telepathyRouter.execute(
            abi.encode(
                messageParams.blockNumber, messageParams.accountProof, messageParams.storageProof
            ),
            messageParams.message
        );
    }

    function test_RevertExecuteMessage_WhenWrongSourceAMBV2Address() public {
        ExecuteMessageFromStorageParams memory messageParams = parseParams("storage1");
        messageParams.sourceAMBAddress = address(0x1234); // Set the sourceAMBAddress to something incorrect
        getDefaultContractSetup(messageParams);

        vm.expectRevert();
        // The MPT verification should fail since the SourceAMBV2 address provided is different than the one in the account proof
        vm.prank(zkRelayer);
        telepathyRouter.execute(
            abi.encode(
                messageParams.blockNumber, messageParams.accountProof, messageParams.storageProof
            ),
            messageParams.message
        );
    }

    function test_ExecuteMessage_WrongTargetAMBV2Fails() public {
        ExecuteMessageFromStorageParams memory messageParams = parseParams("storage1");
        getDefaultContractSetup(messageParams);

        address randomTargetAMBV2 = address(0x1234);
        simpleHandler.setParams(
            simpleHandler.sourceChain(), simpleHandler.sourceAddress(), randomTargetAMBV2
        );

        // Finally, execute the message and check that it failed
        vm.expectRevert();
        vm.prank(zkRelayer);
        telepathyRouter.execute(
            abi.encode(
                messageParams.blockNumber, messageParams.accountProof, messageParams.storageProof
            ),
            messageParams.message
        );
        assertFalse(
            telepathyRouter.messageStatus(messageParams.message.getId())
                == MessageStatus.EXECUTION_SUCCEEDED
        );

        assertEq(simpleHandler.nonce(), 0);
    }

    function test_RevertExecuteMessage_WhenInvalidDestination() public {
        // Test what happens when the destination address doesn't implement the ITelepathyHandlerV2
        ExecuteMessageFromStorageParams memory messageParams = parseParams("storage1");
        getDefaultContractSetup(messageParams);

        // Set the simpleHandler code to random bytes
        bytes memory randomCode = hex"1234";
        vm.etch(address(0), randomCode);

        vm.expectRevert();
        vm.prank(zkRelayer);
        telepathyRouter.execute(
            abi.encode(
                messageParams.blockNumber, messageParams.accountProof, messageParams.storageProof
            ),
            messageParams.message
        );
    }

    function test_RevertExecuteMessage_WrongSrcChain() public {
        ExecuteMessageFromStorageParams memory messageParams = parseParams("storage1");
        messageParams.SOURCE_CHAIN = 6; // Set the source chain to something other than 5
        getDefaultContractSetup(messageParams);

        vm.expectRevert();
        // Finally, execute the message and check that it failed
        vm.prank(zkRelayer);
        telepathyRouter.execute(
            abi.encode(
                messageParams.blockNumber, messageParams.accountProof, messageParams.storageProof
            ),
            messageParams.message
        );
    }

    function test_RevertExecuteMessage_WhenNotZkRelayer() public {
        // This test is generated using `cli/src/generateTest.ts`
        ExecuteMessageFromStorageParams memory messageParams = parseParams("storage1");
        getDefaultContractSetup(messageParams);

        // Finally, execute the message and check that it succeeded
        vm.expectRevert();
        telepathyRouter.execute(
            abi.encode(
                messageParams.blockNumber, messageParams.accountProof, messageParams.storageProof
            ),
            messageParams.message
        );
    }

    function test_ExecuteMessage_WhenCached() public {
        ExecuteMessageFromStorageParams memory messageParams1 = parseParams("storage1");
        ExecuteMessageFromStorageParams memory messageParams2 = parseParams("storage2");
        ExecuteMessageFromStorageParams memory messageParams3 = parseParams("storage3");
        getDefaultContractSetup(messageParams1);

        bytes32 cacheKey1 = keccak256(
            abi.encodePacked(
                messageParams1.SOURCE_CHAIN,
                messageParams1.blockNumber,
                storageVerifier.telepathyRouters(messageParams1.SOURCE_CHAIN)
            )
        );
        assertEq(storageVerifier.storageRootCache(cacheKey1), bytes32(0));

        vm.prank(zkRelayer);
        telepathyRouter.execute(
            abi.encode(
                messageParams1.blockNumber, messageParams1.accountProof, messageParams1.storageProof
            ),
            messageParams1.message
        );

        bytes32 cacheKey2 = keccak256(
            abi.encodePacked(
                messageParams2.SOURCE_CHAIN,
                messageParams2.blockNumber,
                storageVerifier.telepathyRouters(messageParams2.SOURCE_CHAIN)
            )
        );
        assertEq(storageVerifier.storageRootCache(cacheKey2), messageParams1.storageRoot);

        vm.prank(zkRelayer);
        telepathyRouter.execute(
            abi.encode(
                messageParams2.blockNumber, messageParams2.accountProof, messageParams2.storageProof
            ),
            messageParams2.message
        );

        bytes32 cacheKey3 = keccak256(
            abi.encodePacked(
                messageParams3.SOURCE_CHAIN,
                messageParams3.blockNumber,
                storageVerifier.telepathyRouters(messageParams3.SOURCE_CHAIN)
            )
        );
        assertEq(storageVerifier.storageRootCache(cacheKey3), messageParams1.storageRoot);

        vm.prank(zkRelayer);
        telepathyRouter.execute(
            abi.encode(
                messageParams3.blockNumber, messageParams3.accountProof, messageParams3.storageProof
            ),
            messageParams3.message
        );
    }

    function testFuzz_RevertExecutionMessage_InvalidProof(bytes[] memory _randomProof) public {
        // We fuzz test what happens when we provide invalid proofs.
        // We fuzz test what happens when we provide invalid messages.
        ExecuteMessageFromStorageParams memory messageParams = parseParams("storage1");
        getDefaultContractSetup(messageParams);

        vm.expectRevert();
        // Finally, execute the message and check that it failed
        vm.prank(zkRelayer);
        telepathyRouter.execute(
            abi.encode(messageParams.blockNumber, _randomProof, messageParams.storageProof),
            messageParams.message
        );

        vm.expectRevert();
        // Finally, execute the message and check that it failed
        vm.prank(zkRelayer);
        telepathyRouter.execute(
            abi.encode(messageParams.blockNumber, messageParams.accountProof, _randomProof),
            messageParams.message
        );
    }

    function testFuzz_RevertExecuteMessage_InvalidMessage(bytes memory _message) public {
        // We fuzz test what happens when we provide invalid messages.
        ExecuteMessageFromStorageParams memory messageParams = parseParams("storage1");
        getDefaultContractSetup(messageParams);

        vm.expectRevert();
        // Finally, execute the message and check that it failed
        vm.prank(zkRelayer);
        telepathyRouter.execute(
            abi.encode(
                messageParams.blockNumber, messageParams.accountProof, messageParams.storageProof
            ),
            _message
        );
    }
}
