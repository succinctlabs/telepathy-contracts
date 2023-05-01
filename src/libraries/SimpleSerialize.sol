pragma solidity 0.8.16;

import {BeaconChainForks} from "src/libraries/BeaconChainForks.sol";

struct BeaconBlockHeader {
    uint64 slot;
    uint64 proposerIndex;
    bytes32 parentRoot;
    bytes32 stateRoot;
    bytes32 bodyRoot;
}

library SSZ {
    uint256 internal constant HISTORICAL_ROOTS_LIMIT = 16777216;
    uint256 internal constant SLOTS_PER_HISTORICAL_ROOT = 8192;

    function toLittleEndian(uint256 v) internal pure returns (bytes32) {
        v = ((v & 0xFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00) >> 8)
            | ((v & 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) << 8);
        v = ((v & 0xFFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000) >> 16)
            | ((v & 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) << 16);
        v = ((v & 0xFFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000) >> 32)
            | ((v & 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) << 32);
        v = ((v & 0xFFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF0000000000000000) >> 64)
            | ((v & 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) << 64);
        v = (v >> 128) | (v << 128);
        return bytes32(v);
    }

    function restoreMerkleRoot(bytes32 leaf, uint256 index, bytes32[] memory branch)
        internal
        pure
        returns (bytes32)
    {
        require(2 ** (branch.length + 1) > index);
        bytes32 value = leaf;
        uint256 i = 0;
        while (index != 1) {
            if (index % 2 == 1) {
                value = sha256(bytes.concat(branch[i], value));
            } else {
                value = sha256(bytes.concat(value, branch[i]));
            }
            index /= 2;
            i++;
        }
        return value;
    }

    function isValidMerkleBranch(bytes32 leaf, uint256 index, bytes32[] memory branch, bytes32 root)
        internal
        pure
        returns (bool)
    {
        bytes32 restoredMerkleRoot = restoreMerkleRoot(leaf, index, branch);
        return root == restoredMerkleRoot;
    }

    function sszBeaconBlockHeader(BeaconBlockHeader memory header)
        internal
        pure
        returns (bytes32)
    {
        bytes32 left = sha256(
            bytes.concat(
                sha256(
                    bytes.concat(toLittleEndian(header.slot), toLittleEndian(header.proposerIndex))
                ),
                sha256(bytes.concat(header.parentRoot, header.stateRoot))
            )
        );
        bytes32 right = sha256(
            bytes.concat(
                sha256(bytes.concat(header.bodyRoot, bytes32(0))),
                sha256(bytes.concat(bytes32(0), bytes32(0)))
            )
        );

        return sha256(bytes.concat(left, right));
    }

    function computeDomain(bytes4 forkVersion, bytes32 genesisValidatorsRoot)
        internal
        pure
        returns (bytes32)
    {
        return bytes32(uint256(0x07 << 248))
            | (sha256(abi.encode(forkVersion, genesisValidatorsRoot)) >> 32);
    }

    function verifyReceiptsRoot(
        bytes32 receiptsRoot,
        bytes32[] memory receiptsRootProof,
        bytes32 headerRoot,
        uint64 srcSlot,
        uint64 txSlot,
        uint32 sourceChainId
    ) internal pure returns (bool) {
        uint256 capellaForkSlot = BeaconChainForks.getCapellaSlot(sourceChainId);

        // In Bellatrix we use state.historical_roots, in Capella we use state.historical_summaries
        // We use < here because capellaForkSlot is the last slot processed using Bellatrix logic;
        // the last batch in state.historical_roots contains the 8192 slots *before* capellaForkSlot.
        uint256 stateToHistoricalGIndex = txSlot < capellaForkSlot ? 7 : 27;

        // The list state.historical_summaries is empty at the beginning of Capella
        uint256 historicalListIndex = txSlot < capellaForkSlot
            ? txSlot / SLOTS_PER_HISTORICAL_ROOT
            : (txSlot - capellaForkSlot) / SLOTS_PER_HISTORICAL_ROOT;

        uint256 index;
        if (srcSlot == txSlot) {
            index = 8 + 3;
            index = index * 2 ** 9 + 387;
        } else if (srcSlot - txSlot <= SLOTS_PER_HISTORICAL_ROOT) {
            index = 8 + 3;
            index = index * 2 ** 5 + 6;
            index = index * SLOTS_PER_HISTORICAL_ROOT + txSlot % SLOTS_PER_HISTORICAL_ROOT;
            index = index * 2 ** 9 + 387;
        } else if (txSlot < srcSlot) {
            index = 8 + 3;
            index = index * 2 ** 5 + stateToHistoricalGIndex;
            index = index * 2 + 0;
            index = index * HISTORICAL_ROOTS_LIMIT + historicalListIndex;
            index = index * 2 + 1;
            index = index * SLOTS_PER_HISTORICAL_ROOT + txSlot % SLOTS_PER_HISTORICAL_ROOT;
            index = index * 2 ** 9 + 387;
        } else {
            revert("TargetAMB: invalid target slot");
        }
        return isValidMerkleBranch(receiptsRoot, index, receiptsRootProof, headerRoot);
    }
}
