pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {MockTelepathy} from "src/amb/mocks/MockTelepathy.sol";
import {TelepathyPubSub} from "src/pubsub/TelepathyPubSub.sol";
import {Subscription} from "src/pubsub/interfaces/IPubSub.sol";
import {TelepathyHandler} from "src/amb/interfaces/TelepathyHandler.sol";
import {TelepathyValidator} from "external/integrations/omnibridge/TelepathyValidator.sol";
import {UUPSProxy} from "src/libraries/Proxy.sol";

interface IForeignAMB {}

interface IForeignBridge {}

interface IBasicHomeAMB {
    function executeAffirmation(bytes calldata message) external;
}

interface IBasicHomeBridge {
    function executeAffirmation(address recipient, uint256 value, bytes32 transactionHash)
        external;
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
    IBasicHomeBridge basicHomeBridge;
    IForeignAMB foreignAMB;
    IForeignBridge foreignBridge;
    TelepathyValidator telepathyValidator;
    address owner = makeAddr("owner");

    uint32 DESTINATION_CHAIN = 100;
    uint32 SOURCE_CHAIN = 1;
    bytes32 public constant AMB_AFFIRMATION_EVENT_SIG =
        keccak256("UserRequestForAffirmation(bytes32,bytes)");

    /// @dev Listen for event Bridge(address indexed from, address indexed to, uint256 value)
    ///      from the token contract in the ERC20-to-Native bridge.
    /// Source: https://github.com/omni/tokenbridge-contracts/blob/908a48107919d4ab127f9af07d44d47eac91547e/contracts/upgradeable_contracts/erc20_to_native/ForeignBridgeErcToNative.sol#LL74C12-L74C12
    bytes32 public constant BRIDGE_AFFIRMATION_EVENT_SIG =
        keccak256("UserRequestForAffirmation(address,uint256)");

    function setUp() public {
        mockTelepathy = new MockTelepathy(DESTINATION_CHAIN);
        telepathyPubSub = new TelepathyPubSub(address(mockTelepathy));

        basicHomeAMB = IBasicHomeAMB(makeAddr("BasicHomeAMB"));
        basicHomeBridge = IBasicHomeBridge(makeAddr("BasicHomeBridge"));
        foreignAMB = IForeignAMB(makeAddr("ForeignAMB"));
        foreignBridge = IForeignBridge(makeAddr("ForeignBridge"));

        TelepathyValidator implementation = new TelepathyValidator();
        UUPSProxy proxy = new UUPSProxy(address(implementation), "");

        telepathyValidator = TelepathyValidator(address(proxy));
        telepathyValidator.initialize(
            address(telepathyPubSub),
            SOURCE_CHAIN,
            address(foreignAMB),
            0,
            0,
            address(basicHomeAMB),
            owner
        );
    }

    function test_SubscribeToAMBAffirmationEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Subscribe(
            keccak256(
                abi.encode(
                    Subscription(
                        SOURCE_CHAIN,
                        address(foreignAMB),
                        address(telepathyValidator),
                        telepathyValidator.AMB_AFFIRMATION_EVENT_SIG()
                    )
                )
            ),
            uint64(0),
            uint64(0),
            Subscription(
                SOURCE_CHAIN,
                address(foreignAMB),
                address(telepathyValidator),
                telepathyValidator.AMB_AFFIRMATION_EVENT_SIG()
            )
        );
        vm.prank(owner);
        telepathyValidator.subscribeToAMBAffirmationEvent();

        assertEq(
            telepathyValidator.ambAffirmationSubscriptionId(),
            keccak256(
                abi.encode(
                    Subscription(
                        SOURCE_CHAIN,
                        address(foreignAMB),
                        address(telepathyValidator),
                        telepathyValidator.AMB_AFFIRMATION_EVENT_SIG()
                    )
                )
            )
        );
    }

    function test_SubscribeToBridgeAffirmationEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Subscribe(
            keccak256(
                abi.encode(
                    Subscription(
                        SOURCE_CHAIN,
                        address(foreignBridge),
                        address(telepathyValidator),
                        telepathyValidator.BRIDGE_AFFIRMATION_EVENT_SIG()
                    )
                )
            ),
            uint64(0),
            uint64(0),
            Subscription(
                SOURCE_CHAIN,
                address(foreignBridge),
                address(telepathyValidator),
                telepathyValidator.BRIDGE_AFFIRMATION_EVENT_SIG()
            )
        );
        vm.prank(owner);
        telepathyValidator.subscribeToBridgeAffirmationEvent();

        assertEq(
            telepathyValidator.bridgeAffirmationSubscriptionId(),
            keccak256(
                abi.encode(
                    Subscription(
                        SOURCE_CHAIN,
                        address(foreignBridge),
                        address(telepathyValidator),
                        telepathyValidator.BRIDGE_AFFIRMATION_EVENT_SIG()
                    )
                )
            )
        );
    }

    function test_ToggleExecuteAffirmations() public {
        assertEq(telepathyValidator.executeAffirmationsEnabled(), false);
        vm.prank(owner);
        telepathyValidator.toggleExecuteAffirmations();
        assertEq(telepathyValidator.executeAffirmationsEnabled(), true);
        vm.prank(owner);
        telepathyValidator.toggleExecuteAffirmations();
        assertEq(telepathyValidator.executeAffirmationsEnabled(), false);
    }
}
