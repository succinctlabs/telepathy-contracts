pragma solidity 0.8.14;
pragma experimental ABIEncoderV2;

import "openzeppelin-contracts/security/ReentrancyGuard.sol";
import "./libraries/MerklePatriciaTrie.sol";
import "src/lightclient/libraries/SimpleSerialize.sol";
import "src/amb/interfaces/IAMB.sol";

contract TargetAMB is IReciever, ReentrancyGuard {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    ILightClient public lightClient;
    mapping(bytes32 => MessageStatus) public messageStatus;
    address public sourceAMB;

    uint256 internal constant HISTORICAL_ROOTS_LIMIT = 16777216;
    uint256 internal constant SLOTS_PER_HISTORICAL_ROOT = 8192;


    constructor(address _lightClient, address _sourceAMB) {
        lightClient = ILightClient(_lightClient);
        sourceAMB = _sourceAMB;
    }

    function executeMessage(
        uint64 slot,
        bytes calldata messageBytes,
        bytes[] calldata accountProof,
        bytes[] calldata storageProof
    ) external nonReentrant {
        Message memory message;
        (
            message.nonce,
            message.sender,
            message.receiver,
            message.chainId,
            message.gasLimit,
            message.data
        ) = abi.decode(messageBytes, (uint256, address, address, uint16, uint256, bytes));
        bytes32 messageRoot = keccak256(messageBytes);

        if (messageStatus[messageRoot] != MessageStatus.NOT_EXECUTED) {
            revert("Message already executed.");
        } else if (message.chainId != block.chainid) {
            revert("Wrong chain.");
        }

        {
            bytes32 executionStateRoot = lightClient.executionStateRoots(slot);
            bytes32 storageRoot = MPT.verifyAccount(accountProof, sourceAMB, executionStateRoot);
            bytes32 slotKey = keccak256(abi.encode(keccak256(abi.encode(message.nonce, 0))));
            uint256 slotValue = MPT.verifyStorage(slotKey, storageRoot, storageProof);

            if (bytes32(slotValue) != messageRoot) {
                revert("Invalid message hash.");
            }
        }

        bool status;
        if ((gasleft() * 63) / 64 <= message.gasLimit + 40000) {
            revert("Insufficient gas");
        } else {
            bytes memory recieveCall = abi.encodeWithSignature(
                "receiveSuccinct(address,bytes)", message.sender, message.data
            );
            (status,) = message.receiver.call{gas: message.gasLimit}(recieveCall);
        }

        if (status) {
            messageStatus[messageRoot] = MessageStatus.EXECUTION_SUCCEEDED;
        } else {
            messageStatus[messageRoot] = MessageStatus.EXECUTION_FAILED;
        }

        emit ExecutedMessage(message.nonce, messageRoot, messageBytes, status);
    }

    function executeMessageFromLog(
        bytes calldata srcSlotTxSlotPack,
        bytes calldata messageBytes,
        bytes32[] calldata receiptsRootProof,
        bytes32 receiptsRoot,
        bytes[] calldata receiptProof, // receipt proof against receipt root
        bytes memory txIndexRLPEncoded,
        uint256 logIndex
    ) external nonReentrant {
        // verify receiptsRoot
        {
            (uint64 srcSlot, uint64 txSlot) = abi.decode(srcSlotTxSlotPack, (uint64, uint64));
            // TODO change this to match real light client
            bytes32 stateRoot = lightClient.headers(srcSlot);
            require(stateRoot != bytes32(0), "TrustlessAMB: stateRoot is missing");

            uint256 index;
            if (txSlot == srcSlot) {
                index = 32 + 24;
                index = index * 16 + 3;
            } else if (txSlot + SLOTS_PER_HISTORICAL_ROOT <= srcSlot) {
                revert("Not implemented yet");
                index = 32 + 7;
                index = index * 2 + 0;
                index = index * HISTORICAL_ROOTS_LIMIT + txSlot / SLOTS_PER_HISTORICAL_ROOT;
                index = index * 2 + 1;
                index = index * SLOTS_PER_HISTORICAL_ROOT + txSlot % SLOTS_PER_HISTORICAL_ROOT;
                index = index * 32 + 24;
                index = index * 16 + 3;
            } else if (txSlot < srcSlot) {
                index = 32 + 6;
                index = index * SLOTS_PER_HISTORICAL_ROOT + txSlot % SLOTS_PER_HISTORICAL_ROOT;
                index = index * 32 + 24;
                index = index * 16 + 3;
            } else {
                revert("TrustlessAMB: invalid target slot");
            }
            // TODO we could reduce gas costs by calling `restoreMerkleRoot` here
            // and not passing in the receiptsRoot
            bool isValid =
                SSZ.isValidMerkleBranch(receiptsRoot, index, receiptsRootProof, stateRoot);
            require(isValid, "TrustlessAMB: invalid receipts root proof");
        }

        Message memory message;
        (
            message.nonce,
            message.sender,
            message.receiver,
            message.chainId,
            message.gasLimit,
            message.data
        ) = abi.decode(messageBytes, (uint256, address, address, uint16, uint256, bytes));
        bytes32 messageRoot = keccak256(messageBytes);

        if (messageStatus[messageRoot] != MessageStatus.NOT_EXECUTED) {
            revert("Message already executed.");
        } else if (message.chainId != block.chainid) {
            revert("Wrong chain.");
        }

        {
            // bytes memory key = rlpIndex(txIndex); // TODO maybe we can save calldata by
            // passing in the txIndex and rlp encode it here
            bytes32 receiptMessageRoot = MPT.verifyAMBReceipt(
                receiptProof, receiptsRoot, txIndexRLPEncoded, logIndex, sourceAMB
            );
            require(receiptMessageRoot == messageRoot, "Invalid message hash.");
        }

        bool status;
        if ((gasleft() * 63) / 64 <= message.gasLimit + 40000) {
            revert("Insufficient gas");
        } else {
            bytes memory recieveCall = abi.encodeWithSignature(
                "receiveSuccinct(address,bytes)", message.sender, message.data
            );
            (status,) = message.receiver.call{gas: message.gasLimit}(recieveCall);
        }

        if (status) {
            messageStatus[messageRoot] = MessageStatus.EXECUTION_SUCCEEDED;
        } else {
            messageStatus[messageRoot] = MessageStatus.EXECUTION_FAILED;
        }

        emit ExecutedMessage(message.nonce, messageRoot, messageBytes, status);
    }
}
