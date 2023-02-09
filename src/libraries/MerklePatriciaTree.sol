pragma solidity 0.8.14;

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
        RLPReader.RLPItem memory valueAsItem = value.toRLPItem();

        // The first byte is a designator for the transaction type, so first we validate the txType.
        // Reference: https://eips.ethereum.org/EIPS/eip-2718
        uint256 ptr = RLPReader.MemoryPointer.unwrap(valueAsItem.ptr);
        bytes memory txType = new bytes(1);
        assembly {
            mstore(add(txType, 32), mload(ptr))
        }
        require(bytes1(txType) == 0x02 || bytes1(txType) == 0x01);

        // Then we truncate the first byte to get the RLP of the receipt.
        valueAsItem.ptr =
            RLPReader.MemoryPointer.wrap(RLPReader.MemoryPointer.unwrap(valueAsItem.ptr) + 1);
        valueAsItem.length--;

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
