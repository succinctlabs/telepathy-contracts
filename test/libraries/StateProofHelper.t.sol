pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {StorageProof, EventProof} from "src/libraries/StateProofHelper.sol";
import {StateProofFixture} from "test/libraries/StateProofFixture.sol";
import {RLPReader} from "@optimism-bedrock/rlp/RLPReader.sol";
import {RLPWriter} from "@optimism-bedrock/rlp/RLPWriter.sol";
import {MerkleTrie} from "@optimism-bedrock/trie/MerkleTrie.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";

contract StateProofHelperTest is Test, StateProofFixture {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;

    uint256 constant STORAGE_PROOF_FIXTURE_START = 8;
    uint256 constant STORAGE_PROOF_FIXTURE_END = 12;
    uint256 constant EVENT_PROOF_FIXTURE_START = 18;
    uint256 constant EVENT_PROOF_FIXTURE_END = 22;

    StorageProofFixture[] storageProofFixtures;
    EventProofFixture[] eventProofFixtures;

    function setUp() public {
        // read all storage proof fixtures
        string memory root = vm.projectRoot();
        for (uint256 i = STORAGE_PROOF_FIXTURE_START; i <= STORAGE_PROOF_FIXTURE_END; i++) {
            uint256 msgNonce = i;

            string memory filename = string.concat("storageProof", Strings.toString(msgNonce));
            string memory path = string.concat(root, "/test/libraries/fixtures/", filename, ".json");
            try vm.readFile(path) returns (string memory file) {
                bytes memory parsed = vm.parseJson(file);
                storageProofFixtures.push(abi.decode(parsed, (StorageProofFixture)));
            } catch {
                continue;
            }
        }

        // read all event proof fixtures
        for (uint256 i = EVENT_PROOF_FIXTURE_START; i <= EVENT_PROOF_FIXTURE_END; i++) {
            uint256 msgNonce = i;

            string memory filename = string.concat("eventProof", Strings.toString(msgNonce));
            string memory path = string.concat(root, "/test/libraries/fixtures/", filename, ".json");
            try vm.readFile(path) returns (string memory file) {
                bytes memory parsed = vm.parseJson(file);
                eventProofFixtures.push(abi.decode(parsed, (EventProofFixture)));
            } catch {
                continue;
            }
        }
    }

    function test_SetUp() public view {
        require(storageProofFixtures.length > 0, "no storageProof fixtures found");
        require(eventProofFixtures.length > 0, "no eventProof fixtures found");
    }

    function test_StorageProof() public view {
        for (uint256 i = 0; i < storageProofFixtures.length; i++) {
            StorageProofFixture memory fixture = storageProofFixtures[i];

            bytes[] memory proof = buildStorageProof(fixture);

            bytes32 storageRoot =
                StorageProof.getStorageRoot(proof, fixture.contractAddress, fixture.stateRootHash);
            require(storageRoot == fixture.storageRoot);
        }
    }

    function test_EventProof() public view {
        for (uint256 i = 0; i < eventProofFixtures.length; i++) {
            EventProofFixture memory fixture = eventProofFixtures[i];

            bytes[] memory proof = buildEventProof(fixture);

            bytes32 messageRoot = EventProof.getEventTopic(
                proof,
                fixture.receiptsRoot,
                vm.parseBytes(fixture.key),
                fixture.logIndex,
                fixture.claimedEmitter,
                keccak256("SentMessage(uint64,bytes32,bytes)"),
                2
            );
            require(messageRoot == fixture.messageRoot);
        }
    }
}
