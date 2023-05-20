pragma solidity ^0.8.16;

import {TelepathyPubSub} from "src/pubsub/TelepathyPubSub.sol";
import {SubscriptionReceiverUpgradeable} from
    "src/pubsub/interfaces/SubscriptionReceiverUpgradeable.sol";
import {Initializable} from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

/// @title TelepathyValidator
/// @author Succinct Labs
/// @notice A validator for the ETH (Foreign) -> Gnosis (Home) bridge that relies on the Telepathy Protocol
///         for proof of consensus in verifying the UserRequestForAffirmation events was emitted on Ethereum.
/// @dev "AMB" refers to the contract for general message passing, where as "Bridge" refers to token transfers.
contract TelepathyValidator is SubscriptionReceiverUpgradeable, OwnableUpgradeable {
    /// @dev Listen for event UserRequestForAffirmation(bytes32 indexed messageId, bytes encodedData)
    ///      where the encodedData is the ABI encoded message from the Foreign AMB.
    /// Source: https://github.com/omni/tokenbridge-contracts/blob/908a48107919d4ab127f9af07d44d47eac91547e/contracts/upgradeable_contracts/arbitrary_message/ForeignAMB.sol#L6
    bytes32 public constant AMB_AFFIRMATION_EVENT_SIG =
        keccak256("UserRequestForAffirmation(bytes32,bytes)");

    /// @dev Listen for event UserRequestForAffirmation(address recipient, uint256 value)
    ///      from the ERC20-to-Native bridge contract.
    /// Source: https://github.com/omni/tokenbridge-contracts/blob/908a48107919d4ab127f9af07d44d47eac91547e/contracts/upgradeable_contracts/erc20_to_native/ForeignBridgeErcToNative.sol#LL74C12-L74C12
    bytes32 public constant BRIDGE_AFFIRMATION_EVENT_SIG =
        keccak256("UserRequestForAffirmation(address,uint256)");

    enum ExecutionStatus {
        NONE,
        PENDING,
        EXECUTED
    }

    // The below variables are only settable at initalization time.
    address public AMB_AFFIRMATION_SOURCE_ADDRESS;
    address public BRIDGE_AFFIRMATION_SOURCE_ADDRESS;
    uint32 public SOURCE_CHAIN_ID;
    uint64 public START_SLOT;
    uint64 public END_SLOT;
    IBasicHomeAMB public HOME_AMB;
    IBasicHomeBridge public HOME_BRIDGE;

    bytes32 public ambAffirmationSubscriptionId;
    bytes32 public bridgeAffirmationSubscriptionId;
    bool public executeAffirmationsEnabled;
    /// @dev Because Bridge affirmations require the 'transactionHash' field and that is not known
    ///      from PubSub, we need to put the affirmations in a pending state first and then execute
    ///      a second call with the transactionHash.
    mapping(bytes32 => ExecutionStatus) public bridgeAffirmationStatuses;

    event AMBAffirmationHandled(
        bytes32 indexed publishKey, bytes32 indexed messageId, bytes eventData
    );
    event BridgeAffirmationHandled(
        bytes32 indexed publishKey, address indexed recipient, uint256 value
    );

    error InvalidSourceChain(uint32 sourceChainId);
    error InvalidSourceAddress(address sourceAddress);
    error InvalidSlot(uint64 slot);
    error InvalidSubscriptionId(bytes32 subscriptionId);
    error AffirmationNotNew(address recipient, uint256 value);
    error AffirmationNotPending(address recipient, uint256 value);

    function initialize(
        address _telepathyPubSub,
        uint32 _sourceChainId,
        address _ambAffirmationSourceAddress,
        address _bridgeAffirmationSourceAddress,
        uint64 _startSlot,
        uint64 _endSlot,
        address _homeAMB,
        address _homeBridge,
        address _owner
    ) external initializer {
        __SubscriptionReceiver_init(_telepathyPubSub);
        __Ownable_init();
        SOURCE_CHAIN_ID = _sourceChainId;
        AMB_AFFIRMATION_SOURCE_ADDRESS = _ambAffirmationSourceAddress;
        BRIDGE_AFFIRMATION_SOURCE_ADDRESS = _bridgeAffirmationSourceAddress;
        START_SLOT = _startSlot;
        END_SLOT = _endSlot;
        HOME_AMB = IBasicHomeAMB(_homeAMB);
        HOME_BRIDGE = IBasicHomeBridge(_homeBridge);
        transferOwnership(_owner);
    }

    function toggleExecuteAffirmations() external onlyOwner {
        executeAffirmationsEnabled = !executeAffirmationsEnabled;
    }

    function subscribeToAMBAffirmationEvent() external onlyOwner returns (bytes32) {
        ambAffirmationSubscriptionId = telepathyPubSub.subscribe(
            SOURCE_CHAIN_ID,
            AMB_AFFIRMATION_SOURCE_ADDRESS,
            address(this),
            AMB_AFFIRMATION_EVENT_SIG,
            START_SLOT,
            END_SLOT
        );
        return ambAffirmationSubscriptionId;
    }

    function subscribeToBridgeAffirmationEvent() external onlyOwner returns (bytes32) {
        bridgeAffirmationSubscriptionId = telepathyPubSub.subscribe(
            SOURCE_CHAIN_ID,
            BRIDGE_AFFIRMATION_SOURCE_ADDRESS,
            address(this),
            BRIDGE_AFFIRMATION_EVENT_SIG,
            START_SLOT,
            END_SLOT
        );
        return bridgeAffirmationSubscriptionId;
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

        if (
            _sourceAddress != AMB_AFFIRMATION_SOURCE_ADDRESS
                && _sourceAddress != BRIDGE_AFFIRMATION_SOURCE_ADDRESS
        ) {
            revert InvalidSourceAddress(_sourceAddress);
        }

        if (
            _subscriptionId != ambAffirmationSubscriptionId
                && _subscriptionId != bridgeAffirmationSubscriptionId
        ) {
            revert InvalidSubscriptionId(_subscriptionId);
        }

        if (_slot < START_SLOT || (END_SLOT != 0 && _slot > END_SLOT)) {
            revert InvalidSlot(_slot);
        }

        bytes32 eventSig = _eventTopics[0];
        if (eventSig == AMB_AFFIRMATION_EVENT_SIG) {
            bytes32 messageId = _eventTopics[1];

            if (executeAffirmationsEnabled) {
                // abi.decode strips away the added offset+length prefix, which is added
                // by Solidity for all dynamic types.
                bytes memory eventData = abi.decode(_eventData, (bytes));
                HOME_AMB.executeAffirmation(eventData);
            }

            emit AMBAffirmationHandled(_publishKey, messageId, _eventData);
        } else if (eventSig == BRIDGE_AFFIRMATION_EVENT_SIG) {
            (address recipient, uint256 value) = abi.decode(_eventData, (address, uint256));

            bytes32 affirmationKey = keccak256(abi.encode(recipient, value));
            if (bridgeAffirmationStatuses[affirmationKey] != ExecutionStatus.NONE) {
                revert AffirmationNotNew(recipient, value);
            }
            bridgeAffirmationStatuses[affirmationKey] = ExecutionStatus.PENDING;

            emit BridgeAffirmationHandled(_publishKey, recipient, value);
        }
    }

    function executeAffirmationForBridge(
        address _recipient,
        uint256 _value,
        bytes32 _transactionHash
    ) public onlyOwner {
        bytes32 affirmationKey = keccak256(abi.encode(_recipient, _value));
        if (bridgeAffirmationStatuses[affirmationKey] != ExecutionStatus.PENDING) {
            revert AffirmationNotPending(_recipient, _value);
        }
        bridgeAffirmationStatuses[affirmationKey] = ExecutionStatus.EXECUTED;

        if (executeAffirmationsEnabled) {
            HOME_BRIDGE.executeAffirmation(_recipient, _value, _transactionHash);
        }
    }
}

interface IBasicHomeAMB {
    function executeAffirmation(bytes calldata message) external;
}

interface IBasicHomeBridge {
    function executeAffirmation(address recipient, uint256 value, bytes32 transactionHash)
        external;
}
