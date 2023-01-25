pragma solidity 0.8.14;

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import {RLPReader} from "Solidity-RLP/RLPReader.sol";

import {SSZ} from "src/libraries/SimpleSerialize.sol";
import {StateProofHelper} from "src/libraries/StateProofHelper.sol";
import {TypeCasts} from "src/libraries/Typecast.sol";
import {ILightClient} from "src/lightclient/interfaces/ILightClient.sol";

import {
    ITelepathyReceiver,
    Message,
    MessageStatus,
    ITelepathyHandler,
    ITelepathyBroadcaster
} from "./interfaces/ITelepathy.sol";

/// @title Telepathy Target Arbitrary Message Bridge
/// @author Succinct Labs
/// @notice Executes the messages sent from the source chain on the target chain.
contract TargetAMB is ITelepathyReceiver, ReentrancyGuard {
    using RLPReader for RLPReader.RLPItem;

    /// @notice The SourceAMB SentMessage event signature used in executeMessageFromLog.
    bytes32 internal constant SENT_MESSAGE_EVENT_SIG =
        keccak256("SentMessage(uint256,bytes32,bytes)");
    /// @notice The topic index of the message root in the SourceAMB SentMessage event.
    uint256 internal constant SENT_MESSAGE_TOPIC_IDX = 2;

    /// @notice The reference light client contract.
    ILightClient public lightClient;

    /// @notice Mapping between a message root and its status.
    mapping(bytes32 => MessageStatus) public messageStatus;

    /// @notice Address of the Telepathy broadcaster on the source chain.
    address public broadcaster;

    constructor(address _lightClient, address _broadcaster) {
        lightClient = ILightClient(_lightClient);
        broadcaster = _broadcaster;
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

        {
            bytes32 executionStateRoot = lightClient.executionStateRoots(slot);
            bytes32 storageRoot =
                StateProofHelper.getStorageRoot(accountProof, broadcaster, executionStateRoot);
            bytes32 slotKey = keccak256(abi.encode(keccak256(abi.encode(message.nonce, 0))));
            uint256 slotValue = StateProofHelper.getStorageValue(slotKey, storageRoot, storageProof);

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
        {
            (uint64 srcSlot, uint64 txSlot) = abi.decode(srcSlotTxSlotPack, (uint64, uint64));
            bytes32 headerRoot = lightClient.headers(srcSlot);
            require(headerRoot != bytes32(0), "TrustlessAMB: headerRoot is missing");
            bool isValid =
                SSZ.verifyReceiptsRoot(receiptsRoot, receiptsRootProof, headerRoot, srcSlot, txSlot);
            require(isValid, "TrustlessAMB: invalid receipts root proof");
        }

        (Message memory message, bytes32 messageRoot) = _checkPreconditions(messageBytes);

        {
            // TODO maybe we can save calldata by passing in the txIndex as a uint and rlp encode it
            // to derive txIndexRLPEncoded instead of passing in `bytes memory txIndexRLPEncoded`
            bytes32 receiptMessageRoot = bytes32(
                StateProofHelper.getEventTopic(
                    receiptProof,
                    receiptsRoot,
                    txIndexRLPEncoded,
                    logIndex,
                    broadcaster,
                    SENT_MESSAGE_EVENT_SIG,
                    SENT_MESSAGE_TOPIC_IDX
                ).toBytes()
            );
            require(receiptMessageRoot == messageRoot, "Invalid message hash.");
        }

        _executeMessage(message, messageRoot, messageBytes);
    }

    /// @notice Decodes the message from messageBytes and checks pre-conditions before message execution
    /// @param messageBytes The message we want to execute provided as bytes.
    function _checkPreconditions(bytes calldata messageBytes)
        internal
        view
        returns (Message memory, bytes32)
    {
        Message memory message = abi.decode(messageBytes, (Message));
        bytes32 messageRoot = keccak256(messageBytes);

        if (messageStatus[messageRoot] != MessageStatus.NOT_EXECUTED) {
            revert("Message already executed.");
        } else if (message.recipientChainId != block.chainid) {
            revert("Wrong chain.");
        }
        return (message, messageRoot);
    }

    /// @notice Executes a message and updates storage with status and emits an event.
    /// @dev Assumes that the message is valid and has not been already executed.
    /// @dev Assumes that message, messageRoot and messageBytes have already been validated to correctly match.
    /// @param message The message we want to execute.
    /// @param messageRoot The message root of the message.
    /// @param messageBytes The message we want to execute provided as bytes for use in the event.
    function _executeMessage(Message memory message, bytes32 messageRoot, bytes memory messageBytes)
        internal
    {
        bool status;
        bytes memory recieveCall = abi.encodeWithSelector(
            ITelepathyHandler.handleTelepathy.selector,
            message.sourceChainId,
            message.senderAddress,
            message.data
        );
        address recipient = TypeCasts.bytes32ToAddress(message.recipientAddress);
        (status,) = recipient.call(recieveCall);

        if (status) {
            messageStatus[messageRoot] = MessageStatus.EXECUTION_SUCCEEDED;
        } else {
            messageStatus[messageRoot] = MessageStatus.EXECUTION_FAILED;
        }

        emit ExecutedMessage(message.nonce, messageRoot, messageBytes, status);
    }
}
