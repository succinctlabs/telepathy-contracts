pragma solidity ^0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MessageStatus} from "src/amb-v2/interfaces/ITelepathy.sol";
import {TelepathyRouterV2} from "src/amb-v2/TelepathyRouter.sol";
import {LightClientMock} from "src/lightclient/LightClientMock.sol";
import {SimpleHandler} from "test/amb-v2/TestUtils.sol";
import {WrappedInitialize} from "test/amb-v2/TestUtils.sol";
import {BeaconChainForks} from "src/libraries/BeaconChainForks.sol";
import {Message} from "src/libraries/Message.sol";
import {Bytes32} from "src/libraries/Typecast.sol";
import {TelepathyEventVerifier} from "src/amb-v2/verifier/TelepathyEventVerifier.sol";
import {VerifierType} from "src/amb-v2/verifier/interfaces/IMessageVerifier.sol";
import {UUPSProxy} from "src/libraries/Proxy.sol";

// The weird ordering here is because vm.parseJSON requires
// alphabetaical ordering of the fields in the struct
struct ExecuteMessageFromLogParams {
    uint32 DEST_CHAIN;
    uint32 SOURCE_CHAIN;
    bytes32 headerRoot;
    uint256 logIndex;
    bytes message;
    bytes[] receiptProof;
    bytes32 receiptsRoot;
    bytes32[] receiptsRootProof;
    address sourceAMBAddress;
    address sourceMessageSender;
    uint64 sourceSlot;
    bytes srcSlotTxSlotPack;
    bytes txIndexRLPEncoded;
}

contract TargetAMBV2EventVerifierTest is Test {
    using Message for bytes;

    LightClientMock beaconLightClient;
    TelepathyRouterV2 telepathyRouter;
    SimpleHandler simpleHandler;
    TelepathyEventVerifier eventVerifier;

    function setUp() public {
        beaconLightClient = new LightClientMock();
    }

    function parseParams(string memory filename)
        internal
        view
        returns (ExecuteMessageFromLogParams memory)
    {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/amb-v2/fixtures/", filename, ".json");
        string memory file = vm.readFile(path);
        bytes memory parsed = vm.parseJson(file);
        ExecuteMessageFromLogParams memory params =
            abi.decode(parsed, (ExecuteMessageFromLogParams));
        return params;
    }

    function getDefaultContractSetup(ExecuteMessageFromLogParams memory testParams) internal {
        vm.chainId(testParams.DEST_CHAIN);

        // Set up the TelepathyRouterV2 contract
        TelepathyRouterV2 targetAMBImpl = new TelepathyRouterV2();
        UUPSProxy proxy = new UUPSProxy(address(targetAMBImpl), "");
        telepathyRouter = TelepathyRouterV2(address(proxy));
        address timelock = makeAddr("timelock");

        (address storageVerifierAddr, address eventVerifierAddr, address attestationVerifierAddr) =
        WrappedInitialize.initializeRouter(
            address(telepathyRouter),
            testParams.SOURCE_CHAIN,
            address(beaconLightClient),
            makeAddr("stateQueryGateway"),
            testParams.sourceAMBAddress,
            timelock,
            address(this)
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

        // Then initialize the contract that will be called by the TargetAMBV2
        SimpleHandler simpleHandlerTemplate = new SimpleHandler();
        vm.etch(address(0), address(simpleHandlerTemplate).code);
        simpleHandler = SimpleHandler(address(0));
        simpleHandler.setParams(
            testParams.SOURCE_CHAIN, testParams.sourceMessageSender, address(telepathyRouter)
        );
        simpleHandler.setVerifierType(VerifierType.ZK_EVENT);

        (uint64 srcSlot,) = abi.decode(testParams.srcSlotTxSlotPack, (uint64, uint64));
        assertEq(srcSlot, testParams.sourceSlot);

        vm.warp(1675221581 - 60 * 10);
        beaconLightClient.setHeader(srcSlot, testParams.headerRoot);
        vm.warp(1675221581);
    }

    function test_ExecuteMessageFromLog_WhenCloseSlot() public {
        // This test is generated using `cli/src/generateTest.ts`
        ExecuteMessageFromLogParams memory testParams = parseParams("closeSlot");
        getDefaultContractSetup(testParams);

        // Execute the message and check that it succeeded
        telepathyRouter.execute(
            abi.encode(
                testParams.srcSlotTxSlotPack,
                testParams.receiptsRootProof,
                testParams.receiptsRoot,
                testParams.receiptProof,
                testParams.txIndexRLPEncoded,
                testParams.logIndex
            ),
            testParams.message
        );
        assertTrue(
            telepathyRouter.messageStatus(testParams.message.getId())
                == MessageStatus.EXECUTION_SUCCEEDED
        );

        // Check that the simpleHandler processed the message correctly
        assertEq(simpleHandler.nonce(), 1);
        bytes32 expectedDataHash = keccak256(abi.encode(address(0), uint256(100)));
        assertEq(simpleHandler.nonceToDataHash(0), expectedDataHash);
    }

    function test_ExecuteMessageFromLog_WhenCloseSlotFail(bytes memory randomBytes) public {
        // TODO add way more fuzz tests messing with various fields

        // This test is generated using `cli/src/generateTest.ts`
        ExecuteMessageFromLogParams memory testParams = parseParams("closeSlot");
        getDefaultContractSetup(testParams);

        vm.expectRevert();
        // Execute the message and make sure that it fails.
        telepathyRouter.execute(
            abi.encode(
                testParams.srcSlotTxSlotPack,
                testParams.receiptsRootProof,
                testParams.receiptsRoot,
                testParams.receiptProof,
                testParams.txIndexRLPEncoded,
                testParams.logIndex
            ),
            randomBytes
        );
    }

    function test_ExecuteMessageFromLog_WhenSameSlot() public {
        // This test is generated using `cli/src/generateTest.ts`
        ExecuteMessageFromLogParams memory testParams = parseParams("sameSlot");
        getDefaultContractSetup(testParams);

        (uint64 srcSlot, uint64 txSlot) = abi.decode(testParams.srcSlotTxSlotPack, (uint64, uint64));
        assertEq(txSlot, srcSlot);

        // Execute the message and check that it succeeded
        telepathyRouter.execute(
            abi.encode(
                testParams.srcSlotTxSlotPack,
                testParams.receiptsRootProof,
                testParams.receiptsRoot,
                testParams.receiptProof,
                testParams.txIndexRLPEncoded,
                testParams.logIndex
            ),
            testParams.message
        );
        assertTrue(
            telepathyRouter.messageStatus(testParams.message.getId())
                == MessageStatus.EXECUTION_SUCCEEDED
        );

        // Check that the simpleHandler processed the message correctly
        assertEq(simpleHandler.nonce(), 1, "Nonce is not 1");
        bytes32 expectedDataHash = keccak256(abi.encode(address(0), uint256(100)));
        assertEq(
            simpleHandler.nonceToDataHash(0),
            expectedDataHash,
            "Data hash not set as expected in SimpleHandler"
        );
    }

    function test_ExecuteMessageFromLog_WhenFarSlot() public {
        // This test is generated using `cli/src/generateTest.ts`
        ExecuteMessageFromLogParams memory testParams = parseParams("farSlot");
        getDefaultContractSetup(testParams);

        // Execute the message and check that it succeeded
        telepathyRouter.execute(
            abi.encode(
                testParams.srcSlotTxSlotPack,
                testParams.receiptsRootProof,
                testParams.receiptsRoot,
                testParams.receiptProof,
                testParams.txIndexRLPEncoded,
                testParams.logIndex
            ),
            testParams.message
        );
        assertTrue(
            telepathyRouter.messageStatus(testParams.message.getId())
                == MessageStatus.EXECUTION_SUCCEEDED
        );

        // Check that the simpleHandler processed the message correctly
        assertEq(simpleHandler.nonce(), 1);
        bytes32 expectedDataHash = keccak256(abi.encode(address(0), uint256(100)));
        assertEq(simpleHandler.nonceToDataHash(0), expectedDataHash);
    }

    function test_ExecuteMessageFromLog_WhenFarSlotBellatrixCapella() public {
        // This test has tx slot in bellatrix, source slot in capella
        ExecuteMessageFromLogParams memory testParams = parseParams("farSlotBellatrixCapella");
        getDefaultContractSetup(testParams);

        (uint64 srcSlot, uint64 txSlot) = abi.decode(testParams.srcSlotTxSlotPack, (uint64, uint64));
        bytes memory message = testParams.message;
        assertTrue(txSlot < BeaconChainForks.getCapellaSlot(message.sourceChainId()));
        assertTrue(srcSlot >= BeaconChainForks.getCapellaSlot(message.sourceChainId()));

        SimpleHandler simpleHandlerTemplate = new SimpleHandler();
        address destination = message.destinationAddress();
        vm.etch(address(destination), address(simpleHandlerTemplate).code);
        simpleHandler = SimpleHandler(address(destination));
        simpleHandler.setParams(
            testParams.SOURCE_CHAIN, message.sourceAddress(), address(telepathyRouter)
        );
        simpleHandler.setVerifierType(VerifierType.ZK_EVENT);

        // Execute the message and check that it succeeded
        telepathyRouter.execute(
            abi.encode(
                testParams.srcSlotTxSlotPack,
                testParams.receiptsRootProof,
                testParams.receiptsRoot,
                testParams.receiptProof,
                testParams.txIndexRLPEncoded,
                testParams.logIndex
            ),
            testParams.message
        );
        assertTrue(
            telepathyRouter.messageStatus(testParams.message.getId())
                == MessageStatus.EXECUTION_SUCCEEDED
        );

        // Check that the simpleHandler processed the message correctly
        assertEq(simpleHandler.nonce(), 1);
        bytes32 expectedDataHash = keccak256(message.data());
        assertEq(simpleHandler.nonceToDataHash(0), expectedDataHash);
    }

    function test_ExecuteMessageFromLog_WhenFarSlotCapellaCapella() public {
        // This test has tx slot in capella, source slot in capella
        ExecuteMessageFromLogParams memory testParams = parseParams("farSlotCapellaCapella");
        getDefaultContractSetup(testParams);

        (uint64 srcSlot, uint64 txSlot) = abi.decode(testParams.srcSlotTxSlotPack, (uint64, uint64));
        bytes memory message = testParams.message;
        assertTrue(txSlot >= BeaconChainForks.getCapellaSlot(message.sourceChainId()));
        assertTrue(srcSlot >= BeaconChainForks.getCapellaSlot(message.sourceChainId()));

        SimpleHandler simpleHandlerTemplate = new SimpleHandler();
        address destination = message.destinationAddress();
        vm.etch(address(destination), address(simpleHandlerTemplate).code);
        simpleHandler = SimpleHandler(address(destination));
        simpleHandler.setParams(
            testParams.SOURCE_CHAIN, message.sourceAddress(), address(telepathyRouter)
        );
        simpleHandler.setVerifierType(VerifierType.ZK_EVENT);

        // Execute the message and check that it succeeded
        telepathyRouter.execute(
            abi.encode(
                testParams.srcSlotTxSlotPack,
                testParams.receiptsRootProof,
                testParams.receiptsRoot,
                testParams.receiptProof,
                testParams.txIndexRLPEncoded,
                testParams.logIndex
            ),
            testParams.message
        );
        assertTrue(
            telepathyRouter.messageStatus(testParams.message.getId())
                == MessageStatus.EXECUTION_SUCCEEDED
        );

        // Check that the simpleHandler processed the message correctly
        assertEq(simpleHandler.nonce(), 1);
        bytes32 expectedDataHash = keccak256(message.data());
        assertEq(simpleHandler.nonceToDataHash(0), expectedDataHash);
    }

    function test_ExecuteMessageFromLog_WhenCloseSlotBoundaryConditions() public {
        // This test is generated using `cli/src/generateTest.ts`
        uint256[] memory diffs = new uint[](3);
        diffs[0] = 8191;
        diffs[1] = 8192;
        diffs[2] = 8193;
        for (uint256 i = 0; i < diffs.length; i++) {
            ExecuteMessageFromLogParams memory testParams =
                parseParams(string.concat("closeSlotDiffEq", Strings.toString(diffs[i])));
            getDefaultContractSetup(testParams);

            (uint64 sourceSlot, uint64 targetSlot) =
                abi.decode(testParams.srcSlotTxSlotPack, (uint64, uint64));
            assertEq(sourceSlot, targetSlot + uint64(diffs[i]));

            // Execute the message and check that it succeeded
            telepathyRouter.execute(
                abi.encode(
                    testParams.srcSlotTxSlotPack,
                    testParams.receiptsRootProof,
                    testParams.receiptsRoot,
                    testParams.receiptProof,
                    testParams.txIndexRLPEncoded,
                    testParams.logIndex
                ),
                testParams.message
            );

            assertTrue(
                telepathyRouter.messageStatus(testParams.message.getId())
                    == MessageStatus.EXECUTION_SUCCEEDED
            );

            // Check that the simpleHandler processed the message correctly
            assertEq(simpleHandler.nonce(), i + 1);
            bytes32 expectedDataHash = keccak256(abi.encode(address(0), uint256(100)));
            assertEq(simpleHandler.nonceToDataHash(i), expectedDataHash);
        }
    }
}
