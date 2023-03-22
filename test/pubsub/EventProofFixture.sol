pragma solidity 0.8.16;

import "forge-std/Common.sol";

contract EventProofFixture is CommonBase {
    struct Fixture {
        address claimedEmitter;
        string key;
        bytes logData;
        uint256 logIndex;
        address logSource;
        bytes32[] logTopics;
        bytes32 messageRoot;
        string[] proof;
        bytes32 receiptsRoot;
    }

    function buildProof(Fixture memory fixture) internal pure returns (bytes[] memory) {
        bytes[] memory proof = new bytes[](3);
        proof[0] = vm.parseBytes(fixture.proof[0]);
        proof[1] = vm.parseBytes(fixture.proof[1]);
        proof[2] = vm.parseBytes(fixture.proof[2]);
        return proof;
    }
}
