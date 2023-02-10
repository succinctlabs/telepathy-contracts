pragma solidity ^0.8.0;

interface ILightClient {
    function consistent() external view returns (bool);

    function head() external view returns (uint256);

    function headers(uint256 slot) external view returns (bytes32);

    function executionStateRoots(uint256 slot) external view returns (bytes32);

    function timestamps(uint256 slot) external view returns (uint256);
}
