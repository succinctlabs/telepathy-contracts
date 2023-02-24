pragma solidity 0.8.16;

import "forge-std/Common.sol";

/// @notice Helper contract for parsing the JSON fixtures, and converting them to the correct types.
/// @dev    The weird ordering here is because vm.parseJSON require alphabetical ordering of the
///         fields in the struct, and odd types with conversions are due to the way the JSON is
///         handled.
contract StateProofFixture is CommonBase {
    struct StorageProofFixture {
        address contractAddress;
        string[] proof;
        bytes32 stateRootHash;
        bytes32 storageRoot;
    }

    struct EventProofFixture {
        address claimedEmitter;
        string key;
        uint256 logIndex;
        bytes32 messageRoot;
        uint256 nonce;
        string[] proof;
        bytes32 receiptsRoot;
    }

    function parseStorageFixture(string memory filename)
        internal
        view
        returns (StorageProofFixture memory)
    {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/libraries/fixtures/", filename, ".json");
        string memory file = vm.readFile(path);
        bytes memory parsed = vm.parseJson(file);
        StorageProofFixture memory params = abi.decode(parsed, (StorageProofFixture));
        return params;
    }

    function parseEventFixture(string memory filename)
        internal
        view
        returns (EventProofFixture memory)
    {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/libraries/fixtures/", filename, ".json");
        string memory file = vm.readFile(path);
        bytes memory parsed = vm.parseJson(file);
        EventProofFixture memory params = abi.decode(parsed, (EventProofFixture));
        return params;
    }

    function buildStorageProof(StorageProofFixture memory fixture)
        internal
        pure
        returns (bytes[] memory)
    {
        bytes[] memory proof = new bytes[](8);
        proof[0] = vm.parseBytes(fixture.proof[0]);
        proof[1] = vm.parseBytes(fixture.proof[1]);
        proof[2] = vm.parseBytes(fixture.proof[2]);
        proof[3] = vm.parseBytes(fixture.proof[3]);
        proof[4] = vm.parseBytes(fixture.proof[4]);
        proof[5] = vm.parseBytes(fixture.proof[5]);
        proof[6] = vm.parseBytes(fixture.proof[6]);
        proof[7] = vm.parseBytes(fixture.proof[7]);
        return proof;
    }

    function buildEventProof(EventProofFixture memory fixture)
        internal
        pure
        returns (bytes[] memory)
    {
        bytes[] memory proof = new bytes[](3);
        proof[0] = vm.parseBytes(fixture.proof[0]);
        proof[1] = vm.parseBytes(fixture.proof[1]);
        proof[2] = vm.parseBytes(fixture.proof[2]);
        return proof;
    }
}
