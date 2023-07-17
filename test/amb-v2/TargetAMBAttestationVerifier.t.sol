// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {Address, Bytes32} from "src/libraries/Typecast.sol";
import {MessageStatus} from "src/amb-v2/interfaces/ITelepathy.sol";
import {TelepathyRouterV2} from "src/amb-v2/TelepathyRouter.sol";
import {SourceAMBV2} from "src/amb-v2/SourceAMB.sol";
import {UUPSProxy} from "src/libraries/Proxy.sol";
import {WrappedInitialize, SimpleHandler} from "test/amb-v2/TestUtils.sol";
import {Message} from "src/libraries/Message.sol";
import {Bytes32, Address} from "src/libraries/Typecast.sol";
import {VerifierType} from "src/amb-v2/verifier/interfaces/IMessageVerifier.sol";
import {StateQueryResponse} from "src/amb-v2/verifier/TelepathyAttestationVerifier.sol";

contract MockStateQueryGateway {
    StateQueryResponse currResponse;

    function currentResponse() external view returns (StateQueryResponse memory) {
        return currResponse;
    }

    function setCurrentResponse(StateQueryResponse memory _response) external {
        currResponse = _response;
    }
}

contract TestErrors {
    error VerifierNotFound(uint256 verifierType);
    error VerificationFailed();

    error InvalidSourceChainLength(uint256 length);
    error TelepathyRouterNotFound(uint32 sourceChainId);
    error TelepathyRouterIncorrect(address telepathyRouter);
    error InvalidResult();
    error InvalidMessageId(bytes32 messageId);
    error InvalidFuncSelector(bytes4 selector);
}

contract TargetAMBV2AttestationVerifier is Test, TestErrors {
    using Message for bytes;

    uint32 constant DESTINATION_CHAIN = 10;
    uint32 constant SOURCE_CHAIN = 42161;
    address constant SOURCE_TELEPATHY_ROUTER = 0x41EA857C32c8Cb42EEFa00AF67862eCFf4eB795a;
    address SOURCE_SENDER = makeAddr("sourceMessageSender");
    address DESTINATION_HANDLER = makeAddr("destMessageReceiver");
    bytes constant MESSAGE_DATA = bytes("hello, world!");

    MockStateQueryGateway mockStateQueryGateway;
    TelepathyRouterV2 telepathyRouter;
    SimpleHandler simpleHandler;

    function setUp() public {
        vm.chainId(DESTINATION_CHAIN);
        mockStateQueryGateway = new MockStateQueryGateway();

        // Set up the TelepathyRouterV2 contract.
        TelepathyRouterV2 targetAMBImpl = new TelepathyRouterV2();
        UUPSProxy proxy = new UUPSProxy(address(targetAMBImpl), "");
        telepathyRouter = TelepathyRouterV2(address(proxy));
        address timelock = makeAddr("timelock");

        (address storageVerifierAddr, address eventVerifierAddr, address attestationVerifierAddr) =
        WrappedInitialize.initializeRouter(
            address(telepathyRouter),
            SOURCE_CHAIN,
            makeAddr("beaconLightClient"),
            address(mockStateQueryGateway),
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
            VerifierType.ATTESTATION_STATE_QUERY, attestationVerifierAddr
        );

        // Setup the SimpleHandler contract which is a TelepathyHandlerV2,
        // called by the TargetAMBV2 after message execution.
        SimpleHandler simpleHandlerTemplate = new SimpleHandler();
        vm.etch(DESTINATION_HANDLER, address(simpleHandlerTemplate).code);
        simpleHandler = SimpleHandler(DESTINATION_HANDLER);
        simpleHandler.setParams(SOURCE_CHAIN, SOURCE_SENDER, address(telepathyRouter));
        simpleHandler.setVerifierType(VerifierType.ATTESTATION_STATE_QUERY);
    }

    function test_ExecuteMessage_WhenAttestationProof() public {
        bytes memory message = Message.encode(
            telepathyRouter.VERSION(),
            0,
            SOURCE_CHAIN,
            SOURCE_SENDER,
            DESTINATION_CHAIN,
            Bytes32.fromAddress(DESTINATION_HANDLER),
            MESSAGE_DATA
        );

        vm.chainId(SOURCE_CHAIN);
        vm.prank(SOURCE_SENDER);
        telepathyRouter.send(DESTINATION_CHAIN, DESTINATION_HANDLER, MESSAGE_DATA);

        bytes memory messageIdBytes = abi.encode(message.getId());
        mockStateQueryGateway.setCurrentResponse(
            StateQueryResponse(
                SOURCE_CHAIN,
                0,
                SOURCE_SENDER,
                SOURCE_TELEPATHY_ROUTER,
                abi.encodeWithSelector(SourceAMBV2.getMessageId.selector, 0),
                messageIdBytes
            )
        );

        vm.chainId(DESTINATION_CHAIN);
        vm.prank(address(mockStateQueryGateway));
        telepathyRouter.execute(hex"", message);

        assertTrue(
            telepathyRouter.messageStatus(message.getId()) == MessageStatus.EXECUTION_SUCCEEDED
        );

        // Check that the simpleHandler processed the message correctly.
        assertEq(simpleHandler.nonce(), 1);
        bytes32 expectedDataHash = keccak256(MESSAGE_DATA);
        assertEq(simpleHandler.nonceToDataHash(0), expectedDataHash);
    }

    function test_RevertExecuteMessage_WhenResponseNotSet() public {
        bytes memory message = Message.encode(
            telepathyRouter.VERSION(),
            0,
            SOURCE_CHAIN,
            SOURCE_SENDER,
            DESTINATION_CHAIN,
            Bytes32.fromAddress(DESTINATION_HANDLER),
            MESSAGE_DATA
        );
        vm.chainId(SOURCE_CHAIN);
        vm.prank(SOURCE_SENDER);
        telepathyRouter.send(DESTINATION_CHAIN, DESTINATION_HANDLER, MESSAGE_DATA);

        vm.chainId(DESTINATION_CHAIN);
        vm.prank(address(mockStateQueryGateway));
        vm.expectRevert(abi.encodeWithSelector(VerificationFailed.selector));
        telepathyRouter.execute(hex"", message);
    }
}
