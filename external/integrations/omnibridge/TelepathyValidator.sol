pragma solidity ^0.8.16;

import {TelepathyPubSub} from "src/pubsub/TelepathyPubSub.sol";
import {SubscriptionReceiverUpgradeable} from
    "src/pubsub/interfaces/SubscriptionReceiverUpgradeable.sol";
import {Initializable} from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

import {IBasicHomeAMB} from "./interfaces/IBasicHomeAMB.sol";
import {ExecutionStatus} from "./interfaces/ITelepathyValidator.sol";

/// @title TelepathyValidator
/// @author Succinct Labs
/// @notice A validator for the ETH (Foreign) -> Omnibridge (Home) bridge that relies on the
///         Telepathy for proof of consensus in verifying the UserRequestForAffirmation events was
///         emitted on Ethereum.
contract TelepathyValidator is SubscriptionReceiverUpgradeable, OwnableUpgradeable {
    /// @notice Listen for UserRequestForAffirmation(bytes32 indexed messageId, bytes encodedData)
    ///         where the encodedData is the ABI encoded message from the Foreign AMB.
    /// Source: https://github.com/omni/tokenbridge-contracts/blob/master/contracts/upgradeable_contracts/arbitrary_message/ForeignAMB.sol#L6
    bytes32 public constant AMB_AFFIRMATION_EVENT_SIG =
        keccak256("UserRequestForAffirmation(bytes32,bytes)");

    /// @notice The address of the ForeignAMB that emits the UserRequestForAffirmation event.
    address public AMB_AFFIRMATION_SOURCE_ADDRESS;

    /// @notice The chain ID of the ForeignAMB that emits the UserRequestForAffirmation event.
    uint32 public SOURCE_CHAIN_ID;

    /// @notice  The slot to start listening for events.
    uint64 public START_SLOT;

    /// @notice The slot to stop listening for events.
    uint64 public END_SLOT;

    /// @notice The HomeAMB that will execute the affirmations.
    IBasicHomeAMB public HOME_AMB;

    /// @notice The subscription ID for the UserRequestForAffirmation event.
    bytes32 public AMB_AFFIRMATION_SUBSCRIPTION_ID;

    /// @notice Whether to execute affirmations or not.
    bool public executeAffirmationsEnabled;

    /// @notice Emitted when an affirmation is handled by the validator.
    event UserRequestForAffirmationHandled(
        bytes32 indexed publishKey, bytes32 indexed messageId, bytes eventData
    );

    error InvalidSourceChain(uint32 sourceChainId);
    error InvalidSourceAddress(address sourceAddress);
    error InvalidSlot(uint64 slot);
    error InvalidSubscriptionId(bytes32 subscriptionId);
    error InvalidEventSignature(bytes32 eventSig);
    error AffirmationNotNew(address recipient, uint256 value);
    error AffirmationNotPending(address recipient, uint256 value);
    error AffirmationNotSupported();
    error ExecuteAffirmationsDisabled();

    /// @notice Initialize the validator.
    function initialize(
        address _telepathyPubSub,
        uint32 _sourceChainId,
        address _ambAffirmationSourceAddress,
        uint64 _startSlot,
        uint64 _endSlot,
        address _homeAMB,
        address _owner
    ) external initializer {
        __SubscriptionReceiver_init(_telepathyPubSub);
        __Ownable_init();
        SOURCE_CHAIN_ID = _sourceChainId;
        AMB_AFFIRMATION_SOURCE_ADDRESS = _ambAffirmationSourceAddress;
        START_SLOT = _startSlot;
        END_SLOT = _endSlot;
        HOME_AMB = IBasicHomeAMB(_homeAMB);
        AMB_AFFIRMATION_SUBSCRIPTION_ID = telepathyPubSub.subscribe(
            SOURCE_CHAIN_ID,
            AMB_AFFIRMATION_SOURCE_ADDRESS,
            address(this),
            AMB_AFFIRMATION_EVENT_SIG,
            START_SLOT,
            END_SLOT
        );
        executeAffirmationsEnabled = true;
        transferOwnership(_owner);
    }

    /// @notice Toggle whether the validator can execute affirmations.
    function toggleExecuteAffirmations() external onlyOwner {
        executeAffirmationsEnabled = !executeAffirmationsEnabled;
    }

    /// @notice Handle the published AMBAffirmation or BridgeAffirmation event by executing the
    ///         affirmation in the HomeAMB or HomeBridge.
    function handlePublishImpl(
        bytes32 _subscriptionId,
        uint32 _sourceChainId,
        address _sourceAddress,
        uint64 _slot,
        bytes32 _publishKey,
        bytes32[] memory _eventTopics,
        bytes memory _eventData
    ) internal override {
        if (_sourceChainId != SOURCE_CHAIN_ID) {
            revert InvalidSourceChain(_sourceChainId);
        }

        if (_sourceAddress != AMB_AFFIRMATION_SOURCE_ADDRESS) {
            revert InvalidSourceAddress(_sourceAddress);
        }

        if (_subscriptionId != AMB_AFFIRMATION_SUBSCRIPTION_ID) {
            revert InvalidSubscriptionId(_subscriptionId);
        }

        if (_slot < START_SLOT || (END_SLOT != 0 && _slot > END_SLOT)) {
            revert InvalidSlot(_slot);
        }

        bytes32 eventSig = _eventTopics[0];
        if (eventSig != AMB_AFFIRMATION_EVENT_SIG) {
            revert InvalidEventSignature(eventSig);
        }

        bytes32 messageId = _eventTopics[1];
        if (executeAffirmationsEnabled) {
            // abi.decode(...) strips away the added offset+length prefix, is added by Solidity for 
            // all dynamic types.
            bytes memory eventData = abi.decode(_eventData, (bytes));
            HOME_AMB.executeAffirmation(eventData);
        }

        emit UserRequestForAffirmationHandled(_publishKey, messageId, _eventData);
    }
}
