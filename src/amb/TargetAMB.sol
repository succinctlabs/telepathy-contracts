pragma solidity 0.8.16;

import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {SSZ} from "src/libraries/SimpleSerialize.sol";
import {StorageProof, EventProof} from "src/libraries/StateProofHelper.sol";
import {Address} from "src/libraries/Typecast.sol";
import {MessageEncoding} from "src/libraries/MessageEncoding.sol";

import {TelepathyStorage} from "./TelepathyStorage.sol";
import {
    ITelepathyHandler,
    ITelepathyReceiver,
    Message,
    MessageStatus
} from "./interfaces/ITelepathy.sol";

/// @title Target Arbitrary Message Bridge
/// @author Succinct Labs
/// @notice Executes messages sent from the source chain on the destination chain.
contract TargetAMB is TelepathyStorage, ReentrancyGuardUpgradeable, ITelepathyReceiver {
    /// @notice The minimum delay for using any information from the light client.
    uint256 public constant MIN_LIGHT_CLIENT_DELAY = 2 minutes;

    /// @notice The ITelepathyBroadcaster SentMessage event signature used in `executeMessageFromLog`.
    bytes32 internal constant SENT_MESSAGE_EVENT_SIG =
        keccak256("SentMessage(uint64,bytes32,bytes)");

    /// @notice The topic index of the message root in the SourceAMB SentMessage event.
    /// @dev Because topic[0] is the hash of the event signature (`SENT_MESSAGE_EVENT_SIG` above),
    ///      the topic index of msgHash is 2.
    uint256 internal constant MSG_HASH_TOPIC_IDX = 2;

    /// @notice The index of the `messages` mapping in TelepathyStorage.sol.
    /// @dev We need this when calling `executeMessage` via storage proofs, as it is used in
    /// getting the slot key.
    uint256 internal constant MESSAGES_MAPPING_STORAGE_INDEX = 1;

    /// @notice Gets the length of the sourceChainIds array.
    /// @return The length of the sourceChainIds array.
    function sourceChainIdsLength() external view returns (uint256) {
        return sourceChainIds.length;
    }

    /// @notice Executes a message given a storage proof.
    /// @param slot Specifies which execution state root should be read from the light client.
    /// @param messageBytes The message we want to execute provided as bytes.
    /// @param accountProof Used to prove the broadcaster's state root.
    /// @param storageProof Used to prove the existence of the message root inside the broadcaster.
    function executeMessage(
        uint64 slot,
        bytes calldata messageBytes,
        bytes[] calldata accountProof,
        bytes[] calldata storageProof
    ) external nonReentrant {
        (Message memory message, bytes32 messageRoot) = _checkPreconditions(messageBytes);
        requireLightClientConsistency(message.sourceChainId);
        requireNotFrozen(message.sourceChainId);

        {
            requireLightClientDelay(slot, message.sourceChainId);

            bytes32 storageRoot;
            bytes32 cacheKey = keccak256(
                abi.encodePacked(message.sourceChainId, slot, broadcasters[message.sourceChainId])
            );

            // If the cache is empty for the cacheKey, then we get the
            // storageRoot using the provided accountProof.
            if (storageRootCache[cacheKey] == 0) {
                bytes32 executionStateRoot =
                    lightClients[message.sourceChainId].executionStateRoots(slot);
                require(executionStateRoot != 0, "Execution State Root is not set");
                storageRoot = StorageProof.getStorageRoot(
                    accountProof, broadcasters[message.sourceChainId], executionStateRoot
                );
                storageRootCache[cacheKey] = storageRoot;
            } else {
                storageRoot = storageRootCache[cacheKey];
            }

            bytes32 slotKey = keccak256(
                abi.encode(keccak256(abi.encode(message.nonce, MESSAGES_MAPPING_STORAGE_INDEX)))
            );
            uint256 slotValue = StorageProof.getStorageValue(slotKey, storageRoot, storageProof);

            if (bytes32(slotValue) != messageRoot) {
                revert("Invalid message hash.");
            }
        }

        _executeMessage(message, messageRoot, messageBytes);
    }

    /// @notice Executes a message given an event proof.
    /// @param srcSlotTxSlotPack The slot where we want to read the header from and the slot where
    ///                          the tx executed, packed as two uint64s.
    /// @param messageBytes The message we want to execute provided as bytes.
    /// @param receiptsRootProof A merkle proof proving the receiptsRoot in the block header.
    /// @param receiptsRoot The receipts root which contains our "SentMessage" event.
    /// @param txIndexRLPEncoded The index of our transaction inside the block RLP encoded.
    /// @param logIndex The index of the event in our transaction.
    function executeMessageFromLog(
        bytes calldata srcSlotTxSlotPack,
        bytes calldata messageBytes,
        bytes32[] calldata receiptsRootProof,
        bytes32 receiptsRoot,
        bytes[] calldata receiptProof,
        bytes memory txIndexRLPEncoded,
        uint256 logIndex
    ) external nonReentrant {
        // Verify receiptsRoot against header from light client
        (Message memory message, bytes32 messageRoot) = _checkPreconditions(messageBytes);
        requireLightClientConsistency(message.sourceChainId);
        requireNotFrozen(message.sourceChainId);

        {
            (uint64 srcSlot, uint64 txSlot) = abi.decode(srcSlotTxSlotPack, (uint64, uint64));
            requireLightClientDelay(srcSlot, message.sourceChainId);
            bytes32 headerRoot = lightClients[message.sourceChainId].headers(srcSlot);
            require(headerRoot != bytes32(0), "HeaderRoot is missing");
            bool isValid =
                SSZ.verifyReceiptsRoot(receiptsRoot, receiptsRootProof, headerRoot, srcSlot, txSlot);
            require(isValid, "Invalid receipts root proof");
        }

        {
            // TODO maybe we can save calldata by passing in the txIndex as a uint and rlp encode it
            // to derive txIndexRLPEncoded instead of passing in `bytes memory txIndexRLPEncoded`
            bytes32 receiptMessageRoot = bytes32(
                EventProof.getEventTopic(
                    receiptProof,
                    receiptsRoot,
                    txIndexRLPEncoded,
                    logIndex,
                    broadcasters[message.sourceChainId],
                    SENT_MESSAGE_EVENT_SIG,
                    MSG_HASH_TOPIC_IDX
                )
            );
            require(receiptMessageRoot == messageRoot, "Invalid message hash.");
        }

        _executeMessage(message, messageRoot, messageBytes);
    }

    /// @notice Checks that the light client for a given chainId is consistent.
    function requireLightClientConsistency(uint32 chainId) internal view {
        require(address(lightClients[chainId]) != address(0), "Light client is not set.");
        require(lightClients[chainId].consistent(), "Light client is inconsistent.");
    }

    /// @notice Checks that the chainId is not frozen.
    function requireNotFrozen(uint32 chainId) internal view {
        require(!frozen[chainId], "Contract is frozen.");
    }

    /// @notice Checks that the light client delay is adequate.
    function requireLightClientDelay(uint64 slot, uint32 chainId) internal view {
        require(address(lightClients[chainId]) != address(0), "Light client is not set.");
        require(lightClients[chainId].timestamps(slot) != 0, "Timestamp is not set for slot.");
        uint256 elapsedTime = block.timestamp - lightClients[chainId].timestamps(slot);
        require(elapsedTime >= MIN_LIGHT_CLIENT_DELAY, "Must wait longer to use this slot.");
    }

    /// @notice Decodes the message from messageBytes and checks conditions before message execution
    /// @param messageBytes The message we want to execute provided as bytes.
    function _checkPreconditions(bytes calldata messageBytes)
        internal
        view
        returns (Message memory, bytes32)
    {
        Message memory message = MessageEncoding.decode(messageBytes);
        bytes32 messageRoot = keccak256(messageBytes);

        if (messageStatus[messageRoot] != MessageStatus.NOT_EXECUTED) {
            revert("Message already executed.");
        } else if (message.destinationChainId != block.chainid) {
            revert("Wrong chain.");
        } else if (message.version != version) {
            revert("Wrong version.");
        } else if (
            address(lightClients[message.sourceChainId]) == address(0)
                || broadcasters[message.sourceChainId] == address(0)
        ) {
            revert("Light client or broadcaster for source chain is not set");
        }
        return (message, messageRoot);
    }

    /// @notice Executes a message and updates storage with status and emits an event.
    /// @dev Assumes that the message is valid and has not been already executed.
    /// @dev Assumes that message, messageRoot and messageBytes have already been validated.
    /// @param message The message we want to execute.
    /// @param messageRoot The message root of the message.
    /// @param messageBytes The message we want to execute provided as bytes for use in the event.
    function _executeMessage(Message memory message, bytes32 messageRoot, bytes memory messageBytes)
        internal
    {
        bool status;
        bytes memory data;
        {
            bytes memory receiveCall = abi.encodeWithSelector(
                ITelepathyHandler.handleTelepathy.selector,
                message.sourceChainId,
                message.sourceAddress,
                message.data
            );
            address destination = Address.fromBytes32(message.destinationAddress);
            (status, data) = destination.call(receiveCall);
        }

        // Unfortunately, there are some edge cases where a call may have a successful status but
        // not have actually called the handler. Thus, we enforce that the handler must return
        // a magic constant that we can check here. To avoid stack underflow / decoding errors, we
        // only decode the returned bytes if one EVM word was returned by the call.
        bool implementsHandler = false;
        if (data.length == 32) {
            (bytes4 magic) = abi.decode(data, (bytes4));
            implementsHandler = magic == ITelepathyHandler.handleTelepathy.selector;
        }

        if (status && implementsHandler) {
            messageStatus[messageRoot] = MessageStatus.EXECUTION_SUCCEEDED;
        } else {
            messageStatus[messageRoot] = MessageStatus.EXECUTION_FAILED;
        }

        emit ExecutedMessage(
            message.sourceChainId, message.nonce, messageRoot, messageBytes, status
        );
    }
}
