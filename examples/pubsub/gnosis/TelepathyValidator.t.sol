pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {MockTelepathy} from "src/amb/mocks/MockTelepathy.sol";
import {TelepathyPubSub} from "src/pubsub/TelepathyPubSub.sol";
import {Subscription} from "src/pubsub/interfaces/IPubSub.sol";
import {TelepathyHandler} from "src/amb/interfaces/TelepathyHandler.sol";
import {TelepathyValidator} from "examples/pubsub/gnosis/TelepathyValidator.sol";

interface IForeignAMB {}

interface IBasicHomeAMB {
    function executeAffirmation(bytes calldata message) external;
}

contract TelepathyValidatorTest is Test {
    event Subscribe(
        bytes32 indexed subscriptionId,
        uint64 indexed startSlot,
        uint64 indexed endSlot,
        Subscription subscription
    );

    MockTelepathy mockTelepathy;
    TelepathyPubSub telepathyPubSub;
    IBasicHomeAMB basicHomeAMB;
    IForeignAMB foreignAMB;
    TelepathyValidator telepathyValidator;
    address owner = makeAddr("owner");

    uint32 DESTINATION_CHAIN = 100;
    uint32 SOURCE_CHAIN = 1;
    bytes32 EVENT_SIG = keccak256("UserRequestForAffirmation(bytes32,bytes)");

    function setUp() public {
        mockTelepathy = new MockTelepathy(DESTINATION_CHAIN);
        telepathyPubSub = new TelepathyPubSub(address(mockTelepathy));

        basicHomeAMB = IBasicHomeAMB(makeAddr("BasicHomeAMB"));
        foreignAMB = IForeignAMB(makeAddr("ForeignAMB"));

        telepathyValidator = new TelepathyValidator(
            address(telepathyPubSub),
            SOURCE_CHAIN,
            address(foreignAMB),
            0,
            0,
            address(basicHomeAMB),
            owner
        );
    }

    function test_SubscribeToAffirmationEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Subscribe(
            keccak256(
                abi.encode(
                    Subscription(
                        SOURCE_CHAIN, address(foreignAMB), address(telepathyValidator), EVENT_SIG
                    )
                )
            ),
            uint64(0),
            uint64(0),
            Subscription(SOURCE_CHAIN, address(foreignAMB), address(telepathyValidator), EVENT_SIG)
        );
        vm.prank(owner);
        telepathyValidator.subscribeToAffirmationEvent();
    }

    function test_toggleExecuteAffirmations() public {
        vm.prank(owner);
        telepathyValidator.toggleExecuteAffirmations();
    }
}
