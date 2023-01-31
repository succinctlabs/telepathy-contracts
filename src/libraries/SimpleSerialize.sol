pragma solidity 0.8.14;

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

    function toLittleEndian(uint256 x) internal pure returns (bytes32) {
        bytes32 res;
        for (uint256 i = 0; i < 32; i++) {
            res = (res << 8) | bytes32(x & 0xff);
            x >>= 8;
        }
        return res;
    }

    function restoreMerkleRoot(bytes32 leaf, uint256 index, bytes32[] memory branch)
        internal
        pure
        returns (bytes32)
    {
        bytes32 value = leaf;
        for (uint256 i = 0; i < branch.length; i++) {
            if ((index / (2 ** i)) % 2 == 1) {
                value = sha256(bytes.concat(branch[i], value));
            } else {
                value = sha256(bytes.concat(value, branch[i]));
            }
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
        uint64 txSlot
    ) internal pure returns (bool) {
        uint256 index;
        if (txSlot == srcSlot) {
            index = 8 + 3;
            index = index * 2 ** 9 + 387;
        } else if (txSlot + SLOTS_PER_HISTORICAL_ROOT <= srcSlot) {
            index = 8 + 3;
            index = index * 2 ** 5 + 7;
            index = index * 2 + 0;
            index = index * HISTORICAL_ROOTS_LIMIT + txSlot / SLOTS_PER_HISTORICAL_ROOT;
            index = index * 2 + 1;
            index = index * SLOTS_PER_HISTORICAL_ROOT + txSlot % SLOTS_PER_HISTORICAL_ROOT;
            index = index * 2 ** 9 + 387;
        } else if (txSlot < srcSlot) {
            index = 8 + 3;
            index = index * 2 ** 5 + 6;
            index = index * SLOTS_PER_HISTORICAL_ROOT + txSlot % SLOTS_PER_HISTORICAL_ROOT;
            index = index * 2 ** 9 + 387;
        } else {
            revert("TrustlessAMB: invalid target slot");
        }
        return isValidMerkleBranch(receiptsRoot, index, receiptsRootProof, headerRoot);
    }
}
