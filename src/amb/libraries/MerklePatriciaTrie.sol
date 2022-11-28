pragma solidity 0.8.14;

import "curve-merkle-oracle/MerklePatriciaProofVerifier.sol";
import "curve-merkle-oracle/StateProofVerifier.sol";
import {RLPReader} from "Solidity-RLP/RLPReader.sol";

library MPT {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    function verifyStorage(bytes32 slotHash, bytes32 storageRoot, bytes[] memory _stateProof)
        internal
        pure
        returns (uint256)
    {
        RLPReader.RLPItem[] memory stateProof = new RLPReader.RLPItem[](_stateProof.length);
        for (uint256 i = 0; i < _stateProof.length; i++) {
            stateProof[i] = RLPReader.toRlpItem(_stateProof[i]);
        }
        // Verify existence of some nullifier
        StateProofVerifier.SlotValue memory slotValue =
            StateProofVerifier.extractSlotValueFromProof(slotHash, storageRoot, stateProof);
        // Check that the validated storage slot is present
        require(slotValue.exists, "Slot value does not exist");
        return slotValue.value;
    }

    function verifyAccount(bytes[] memory proof, address contractAddress, bytes32 stateRoot)
        internal
        pure
        returns (bytes32)
    {
        RLPReader.RLPItem[] memory accountProof = new RLPReader.RLPItem[](proof.length);
        for (uint256 i = 0; i < proof.length; i++) {
            accountProof[i] = RLPReader.toRlpItem(proof[i]);
        }
        bytes32 addressHash = keccak256(abi.encodePacked(contractAddress));
        StateProofVerifier.Account memory account =
            StateProofVerifier.extractAccountFromProof(addressHash, stateRoot, accountProof);
        require(account.exists, "Account does not exist");
        return account.storageRoot;
    }

    function verifyAMBReceipt(
        bytes[] memory proof,
        bytes32 receiptRoot,
        bytes memory key,
        uint256 logIndex,
        address claimedEmitter
    ) internal pure returns (bytes32) {
        RLPReader.RLPItem[] memory proofAsRLP = new RLPReader.RLPItem[](proof.length);
        for (uint256 i = 0; i < proof.length; i++) {
            proofAsRLP[i] = RLPReader.toRlpItem(proof[i]);
        }
        bytes memory value =
            MerklePatriciaProofVerifier.extractProofValue(receiptRoot, key, proofAsRLP);
        RLPReader.RLPItem memory valueAsItem = value.toRlpItem();
        if (!valueAsItem.isList()) {
            // TODO: why do we do this ...
            valueAsItem.memPtr++;
            valueAsItem.len--;
        }
        RLPReader.RLPItem[] memory valueAsList = valueAsItem.toList();
        require(valueAsList.length == 4, "Invalid receipt length");
        // In the receipt, the 4th entry is the logs
        RLPReader.RLPItem[] memory logs = valueAsList[3].toList();
        require(logIndex < logs.length, "Log index out of bounds");
        RLPReader.RLPItem[] memory relevantLog = logs[logIndex].toList();
        require(relevantLog.length == 3, "Log has incorrect number of fields");
        // this is the address of the contract that emitted the event
        address contractAddress = relevantLog[0].toAddress();
        require(contractAddress == claimedEmitter, "TrustlessAMB: invalid event emitter");
        RLPReader.RLPItem[] memory topics = relevantLog[1].toList();
        // This is the hash of the event signature, this is hardcoded
        require(
            bytes32(topics[0].toUintStrict()) == keccak256("SentMessage(uint256,bytes32,bytes)"),
            "TruslessAMB: different event signature expected"
        );
        return bytes32(topics[2].toBytes());
    }
}
