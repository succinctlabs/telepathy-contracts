pragma solidity 0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {Strings} from "openzeppelin-contracts/utils/Strings.sol";
import {MessageStatus, ITelepathyHandler, Message} from "src/amb/interfaces/ITelepathy.sol";
import {TelepathyRouter} from "src/amb/TelepathyRouter.sol";
import {SSZ} from "src/libraries/SimpleSerialize.sol";
import {UUPSProxy} from "src/libraries/Proxy.sol";
import {LightClientMock} from "./LightClientMock.sol";
import {SimpleHandler} from "./TargetAMB.t.sol";
import {WrappedInitialize} from "./TargetAMB.t.sol";

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

contract TargetAMBTest is Test {
    LightClientMock lightClientMock;
    TelepathyRouter targetAMB;
    SimpleHandler simpleHandler;

    function setUp() public {
        lightClientMock = new LightClientMock();
    }

    function parseParams(string memory filename)
        internal
        view
        returns (ExecuteMessageFromLogParams memory)
    {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/amb/fixtures/", filename, ".json");
        string memory file = vm.readFile(path);
        bytes memory parsed = vm.parseJson(file);
        ExecuteMessageFromLogParams memory params =
            abi.decode(parsed, (ExecuteMessageFromLogParams));
        return params;
    }

    function getDefaultContractSetup(ExecuteMessageFromLogParams memory testParams) internal {
        vm.chainId(testParams.DEST_CHAIN);

        // First initialize the TargetAMB using the deployed SourceAMB
        TelepathyRouter targetAMBImplementation = new TelepathyRouter();

        UUPSProxy proxy = new UUPSProxy(address(targetAMBImplementation), "");

        targetAMB = TelepathyRouter(address(proxy));
        WrappedInitialize.init(
            address(targetAMB),
            testParams.SOURCE_CHAIN,
            address(lightClientMock),
            testParams.sourceAMBAddress,
            address(this),
            address(this)
        );

        // Then initialize the contract that will be called by the TargetAMB
        SimpleHandler simpleHandlerTemplate = new SimpleHandler();
        vm.etch(address(0), address(simpleHandlerTemplate).code);
        simpleHandler = SimpleHandler(address(0));
        simpleHandler.setParams(
            testParams.SOURCE_CHAIN, testParams.sourceMessageSender, address(targetAMB)
        );

        (uint64 srcSlot,) = abi.decode(testParams.srcSlotTxSlotPack, (uint64, uint64));
        assertEq(srcSlot, testParams.sourceSlot);

        vm.warp(1675221581 - 60 * 10);
        lightClientMock.setHeader(srcSlot, testParams.headerRoot);
        vm.warp(1675221581);
    }

    function test_ExecuteMessageFromLog_WhenCloseSlot() public {
        // This test is generated using `cli/src/generateTest.ts`
        ExecuteMessageFromLogParams memory testParams = parseParams("closeSlot");
        getDefaultContractSetup(testParams);

        // Execute the message and check that it succeeded
        targetAMB.executeMessageFromLog(
            testParams.srcSlotTxSlotPack,
            testParams.message,
            testParams.receiptsRootProof,
            testParams.receiptsRoot,
            testParams.receiptProof,
            testParams.txIndexRLPEncoded,
            testParams.logIndex
        );
        bytes32 messageRoot = keccak256(testParams.message);
        assertTrue(targetAMB.messageStatus(messageRoot) == MessageStatus.EXECUTION_SUCCEEDED);

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
        targetAMB.executeMessageFromLog(
            testParams.srcSlotTxSlotPack,
            randomBytes,
            testParams.receiptsRootProof,
            testParams.receiptsRoot,
            testParams.receiptProof,
            testParams.txIndexRLPEncoded,
            testParams.logIndex
        );
    }

    function test_ExecuteMessageFromLog_WhenSameSlot() public {
        // This test is generated using `cli/src/generateTest.ts`
        ExecuteMessageFromLogParams memory testParams = parseParams("sameSlot");
        getDefaultContractSetup(testParams);

        (uint64 srcSlot, uint64 txSlot) = abi.decode(testParams.srcSlotTxSlotPack, (uint64, uint64));
        assertEq(txSlot, srcSlot);

        // Execute the message and check that it succeeded
        targetAMB.executeMessageFromLog(
            testParams.srcSlotTxSlotPack,
            testParams.message,
            testParams.receiptsRootProof,
            testParams.receiptsRoot,
            testParams.receiptProof,
            testParams.txIndexRLPEncoded,
            testParams.logIndex
        );
        bytes32 messageRoot = keccak256(testParams.message);
        assertTrue(targetAMB.messageStatus(messageRoot) == MessageStatus.EXECUTION_SUCCEEDED);

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
        targetAMB.executeMessageFromLog(
            testParams.srcSlotTxSlotPack,
            testParams.message,
            testParams.receiptsRootProof,
            testParams.receiptsRoot,
            testParams.receiptProof,
            testParams.txIndexRLPEncoded,
            testParams.logIndex
        );
        bytes32 messageRoot = keccak256(testParams.message);
        assertTrue(targetAMB.messageStatus(messageRoot) == MessageStatus.EXECUTION_SUCCEEDED);

        // Check that the simpleHandler processed the message correctly
        assertEq(simpleHandler.nonce(), 1);
        bytes32 expectedDataHash = keccak256(abi.encode(address(0), uint256(100)));
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
            targetAMB.executeMessageFromLog(
                testParams.srcSlotTxSlotPack,
                testParams.message,
                testParams.receiptsRootProof,
                testParams.receiptsRoot,
                testParams.receiptProof,
                testParams.txIndexRLPEncoded,
                testParams.logIndex
            );
            bytes32 messageRoot = keccak256(testParams.message);
            assertTrue(targetAMB.messageStatus(messageRoot) == MessageStatus.EXECUTION_SUCCEEDED);

            // Check that the simpleHandler processed the message correctly
            assertEq(simpleHandler.nonce(), i + 1);
            bytes32 expectedDataHash = keccak256(abi.encode(address(0), uint256(100)));
            assertEq(simpleHandler.nonceToDataHash(i), expectedDataHash);
        }
    }
}
