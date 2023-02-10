pragma solidity 0.8.14;

contract SourceAMBStorage {
    /// @notice Mapping between a nonce and a message root.
    mapping(uint256 => bytes32) public messages;

    /// @notice Keeps track of the next nonce to be used.
    uint256 public nonce = 1;
}
