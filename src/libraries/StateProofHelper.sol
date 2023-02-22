pragma solidity 0.8.16;

import {RLPReader} from "@optimism-bedrock/rlp/RLPReader.sol";
import {RLPWriter} from "@optimism-bedrock/rlp/RLPWriter.sol";
import {MerkleTrie} from "@optimism-bedrock/trie/MerkleTrie.sol";

library StorageProof {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    function getStorageValue(bytes32 slotHash, bytes32 storageRoot, bytes[] memory _stateProof)
        internal
        pure
        returns (uint256)
    {
        bytes memory valueRlpBytes =
            MerkleTrie.get(abi.encodePacked(slotHash), _stateProof, storageRoot);
        require(valueRlpBytes.length > 0, "Storage value does not exist");
        return valueRlpBytes.toRLPItem().readUint256();
    }

    function getStorageRoot(bytes[] memory proof, address contractAddress, bytes32 stateRoot)
        internal
        pure
        returns (bytes32)
    {
        bytes32 addressHash = keccak256(abi.encodePacked(contractAddress));
        bytes memory acctRlpBytes = MerkleTrie.get(abi.encodePacked(addressHash), proof, stateRoot);
        require(acctRlpBytes.length > 0, "Account does not exist");
        RLPReader.RLPItem[] memory acctFields = acctRlpBytes.toRLPItem().readList();
        require(acctFields.length == 4);
        return bytes32(acctFields[2].readUint256());
    }
}

library EventProof {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    function getEventTopic(
        bytes[] memory proof,
        bytes32 receiptRoot,
        bytes memory key,
        uint256 logIndex,
        address claimedEmitter,
        bytes32 eventSignature,
        uint256 topicIndex
    ) internal pure returns (bytes32) {
        bytes memory value = MerkleTrie.get(key, proof, receiptRoot);
        bytes1 txTypeOrFirstByte = value[0];

        // Currently, there are three possible transaction types on Ethereum. Receipts either come
        // in the form "TransactionType | ReceiptPayload" or "ReceiptPayload". The currently
        // supported set of transaction types are 0x01 and 0x02. In this case, we must truncate
        // the first byte to access the payload. To detect the other case, we can use the fact
        // that the first byte of a RLP-encoded list will always be greater than 0xc0.
        // Reference 1: https://eips.ethereum.org/EIPS/eip-2718
        // Reference 2: https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp
        uint256 offset;
        if (txTypeOrFirstByte == 0x01 || txTypeOrFirstByte == 0x02) {
            offset = 1;
        } else if (txTypeOrFirstByte >= 0xc0) {
            offset = 0;
        } else {
            revert("Unsupported transaction type");
        }

        // Truncate the first byte if eneded and get the RLP decoding of the receipt.
        uint256 ptr;
        assembly {
            ptr := add(value, 32)
        }
        RLPReader.RLPItem memory valueAsItem = RLPReader.RLPItem({
            length: value.length - offset,
            ptr: RLPReader.MemoryPointer.wrap(ptr + offset)
        });

        // The length of the receipt must be at least four, as the fourth entry contains events
        RLPReader.RLPItem[] memory valueAsList = valueAsItem.readList();
        require(valueAsList.length == 4, "Invalid receipt length");

        // Read the logs from the receipts and check that it is not ill-formed
        RLPReader.RLPItem[] memory logs = valueAsList[3].readList();
        require(logIndex < logs.length, "Log index out of bounds");
        RLPReader.RLPItem[] memory relevantLog = logs[logIndex].readList();
        require(relevantLog.length == 3, "Log has incorrect number of fields");

        // Validate that the correct contract emitted the event
        address contractAddress = relevantLog[0].readAddress();
        require(contractAddress == claimedEmitter, "Event was not emitted by claimedEmitter");
        RLPReader.RLPItem[] memory topics = relevantLog[1].readList();

        // Validate that the correct event was emitted by checking the event signature
        require(
            bytes32(topics[0].readUint256()) == eventSignature,
            "Event signature does not match eventSignature"
        );

        return topics[topicIndex].readBytes32();
    }
}
