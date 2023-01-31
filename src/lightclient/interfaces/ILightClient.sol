pragma solidity 0.8.14;

interface ILightClient {
    function head() external view returns (uint256);

    function executionStateRoots(uint256 slot) external view returns (bytes32);

    function headers(uint256 slot) external view returns (bytes32);
}
