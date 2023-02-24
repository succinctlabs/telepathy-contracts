pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {StorageProof, EventProof} from "src/libraries/StateProofHelper.sol";
import {StateProofFixture} from "test/libraries/StateProofFixture.sol";
import {RLPReader} from "@optimism-bedrock/rlp/RLPReader.sol";
import {RLPWriter} from "@optimism-bedrock/rlp/RLPWriter.sol";
import {MerkleTrie} from "@optimism-bedrock/trie/MerkleTrie.sol";

contract StateProofHelperTest is Test, StateProofFixture {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;

    function test_AccountProof() public view {
        StorageProofFixture memory fixture = parseStorageFixture("storageProof");

        bytes[] memory proof = buildStorageProof(fixture);

        bytes32 storageRoot =
            StorageProof.getStorageRoot(proof, fixture.contractAddress, fixture.stateRootHash);

        require(storageRoot == fixture.storageRoot);
    }

    function test_EventProof() public view {
        EventProofFixture memory fixture = parseEventFixture("eventProof");

        bytes[] memory proof = buildEventProof(fixture);

        bytes32 nonce = EventProof.getEventTopic(
            proof,
            fixture.receiptsRoot,
            vm.parseBytes(fixture.key),
            fixture.logIndex,
            fixture.claimedEmitter,
            keccak256("SentMessage(uint256,bytes32,bytes)"),
            1
        );
        require(uint256(nonce) == fixture.nonce);

        bytes32 messageRoot = EventProof.getEventTopic(
            proof,
            fixture.receiptsRoot,
            vm.parseBytes(fixture.key),
            fixture.logIndex,
            fixture.claimedEmitter,
            keccak256("SentMessage(uint256,bytes32,bytes)"),
            2
        );
        require(messageRoot == fixture.messageRoot);
    }
}
