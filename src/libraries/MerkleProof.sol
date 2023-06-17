// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

library MerkleProof {
    function verifyProof(bytes32 _root, bytes32 _leaf, bytes32[] memory _proof, uint256 _index)
        public
        pure
        returns (bool)
    {
        bytes32 computedHash = _leaf;

        for (uint256 i = 0; i < _proof.length; i++) {
            if (_index % 2 == 0) {
                computedHash = keccak256(abi.encodePacked(computedHash, _proof[i]));
            } else {
                computedHash = keccak256(abi.encodePacked(_proof[i], computedHash));
            }
            _index = _index / 2;
        }

        return computedHash == _root;
    }

    function getProof(bytes32[] memory nodes, uint256 index)
        public
        pure
        returns (bytes32[] memory)
    {
        // Build the tree
        uint256 treeHeight = ceilLog2(nodes.length);
        bytes32[][] memory tree = new bytes32[][](treeHeight + 1);
        tree[0] = nodes;

        for (uint256 i = 1; i <= treeHeight; i++) {
            uint256 previousLevelLength = tree[i - 1].length;
            bytes32[] memory currentLevel = new bytes32[](previousLevelLength / 2);

            for (uint256 j = 0; j < previousLevelLength; j += 2) {
                currentLevel[j / 2] =
                    keccak256(abi.encodePacked(tree[i - 1][j], tree[i - 1][j + 1]));
            }

            tree[i] = currentLevel;
        }

        // Generate the proof
        bytes32[] memory proof = new bytes32[](treeHeight);
        for (uint256 i = 0; i < treeHeight; i++) {
            if (index % 2 == 0) {
                // sibling is on the right
                proof[i] = tree[i][index + 1];
            } else {
                // sibling is on the left
                proof[i] = tree[i][index - 1];
            }

            index = index / 2;
        }

        return proof;
    }

    function ceilLog2(uint256 _x) private pure returns (uint256 y) {
        require(_x != 0);
        y = (_x & (_x - 1)) == 0 ? 0 : 1;
        while (_x > 1) {
            _x >>= 1;
            y += 1;
        }
        return y;
    }
}
