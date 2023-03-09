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

    // For testing https://eips.ethereum.org/EIPS/eip-2718, which allows for multiple
    // transaction types:
    //  0x?? - LegacyTransaction with RLP byte in range 0xc0 ≤ x ≤ 0xfe
    //  0x01 - Transaction with EIP-2930 Access Lists (https://eips.ethereum.org/EIPS/eip-2930)
    //  0x02 - Transaction with EIP-1559 Fee Market Change (https://eips.ethereum.org/EIPS/eip-1559)

    // Generate fixture for different types by manipulating `TX_TYPE` in the generate proof fixture
    // script.

    function test_EventProof_WhenType0Tx() public view {
        string memory filename = string.concat("eventProof-type0");
        string memory path =
            string.concat(vm.projectRoot(), "/test/libraries/fixtures/", filename, ".json");
        bytes memory parsed = vm.parseJson(vm.readFile(path));
        EventProofFixture memory fixture = abi.decode(parsed, (EventProofFixture));

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

    function test_EventProof_WhenType1Tx() public view {
        string memory filename = string.concat("eventProof-type1");
        string memory path =
            string.concat(vm.projectRoot(), "/test/libraries/fixtures/", filename, ".json");
        bytes memory parsed = vm.parseJson(vm.readFile(path));
        EventProofFixture memory fixture = abi.decode(parsed, (EventProofFixture));

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

    function test_EventProof_WhenType2Tx() public view {
        string memory filename = string.concat("eventProof-type2");
        string memory path =
            string.concat(vm.projectRoot(), "/test/libraries/fixtures/", filename, ".json");
        bytes memory parsed = vm.parseJson(vm.readFile(path));
        EventProofFixture memory fixture = abi.decode(parsed, (EventProofFixture));

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

    function test_RevertStorageProof_WhenBadContractAddress() public {
        StorageProofFixture memory fixture = storageProofFixtures[0];

        fixture.contractAddress = address(0x0);

        bytes[] memory proof = buildStorageProof(fixture);

        vm.expectRevert();
        StorageProof.getStorageRoot(proof, fixture.contractAddress, fixture.stateRootHash);
    }

    function test_ReverStorageProof_WhenBadProof() public {
        StorageProofFixture memory fixture = storageProofFixtures[0];

        fixture.proof[0] = "";

        bytes[] memory proof = buildStorageProof(fixture);

        vm.expectRevert();
        StorageProof.getStorageRoot(proof, fixture.contractAddress, fixture.stateRootHash);
    }

    function test_RevertStorageProof_WhenBadStateRootHash() public {
        StorageProofFixture memory fixture = storageProofFixtures[0];

        fixture.stateRootHash = bytes32(0x0);

        bytes[] memory proof = buildStorageProof(fixture);

        vm.expectRevert();
        StorageProof.getStorageRoot(proof, fixture.contractAddress, fixture.stateRootHash);
    }

    function test_RevertEventProof_WhenBadClaimedEmitter() public {
        EventProofFixture memory fixture = eventProofFixtures[0];

        fixture.claimedEmitter = address(0x0);

        bytes[] memory proof = buildEventProof(fixture);

        vm.expectRevert();
        EventProof.getEventTopic(
            proof,
            fixture.receiptsRoot,
            vm.parseBytes(fixture.key),
            fixture.logIndex,
            fixture.claimedEmitter,
            keccak256("SentMessage(uint64,bytes32,bytes)"),
            2
        );
    }

    function test_RevertEventProof_WhenBadKey() public {
        EventProofFixture memory fixture = eventProofFixtures[0];

        fixture.key = "";

        bytes[] memory proof = buildEventProof(fixture);

        vm.expectRevert();
        EventProof.getEventTopic(
            proof,
            fixture.receiptsRoot,
            vm.parseBytes(fixture.key),
            fixture.logIndex,
            fixture.claimedEmitter,
            keccak256("SentMessage(uint64,bytes32,bytes)"),
            2
        );
    }

    function test_RevertEventProof_WhenBadLogIndex() public {
        EventProofFixture memory fixture = eventProofFixtures[0];

        fixture.logIndex = UINT256_MAX; // 0 is a valid log index, so we use the max int

        bytes[] memory proof = buildEventProof(fixture);

        vm.expectRevert();
        EventProof.getEventTopic(
            proof,
            fixture.receiptsRoot,
            vm.parseBytes(fixture.key),
            fixture.logIndex,
            fixture.claimedEmitter,
            keccak256("SentMessage(uint64,bytes32,bytes)"),
            2
        );
    }

    function test_RevertEventProof_WhenBadProof() public {
        EventProofFixture memory fixture = eventProofFixtures[0];

        fixture.proof[0] = "";

        bytes[] memory proof = buildEventProof(fixture);

        vm.expectRevert();
        EventProof.getEventTopic(
            proof,
            fixture.receiptsRoot,
            vm.parseBytes(fixture.key),
            fixture.logIndex,
            fixture.claimedEmitter,
            keccak256("SentMessage(uint64,bytes32,bytes)"),
            2
        );
    }

    function test_RevertEventProof_WhenBadReceiptsRoot() public {
        EventProofFixture memory fixture = eventProofFixtures[0];

        fixture.receiptsRoot = bytes32(0x0);

        bytes[] memory proof = buildEventProof(fixture);

        vm.expectRevert();
        EventProof.getEventTopic(
            proof,
            fixture.receiptsRoot,
            vm.parseBytes(fixture.key),
            fixture.logIndex,
            fixture.claimedEmitter,
            keccak256("SentMessage(uint64,bytes32,bytes)"),
            2
        );
    }
}
