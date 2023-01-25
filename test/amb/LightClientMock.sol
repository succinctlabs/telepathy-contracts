pragma solidity 0.8.14;

// We must import X as Y so that ILightClient doesn't conflict when we try to import
// both LightClientMock and TargetAMB in the same test file.
import {ILightClient as ILightClientMock} from "src/lightclient/interfaces/ILightClient.sol";

contract LightClientMock is ILightClientMock {
    uint256 public head;
    mapping(uint256 => bytes32) public headers;
    mapping(uint256 => bytes32) public executionStateRoots;

    event HeadUpdate(uint256 indexed slot, bytes32 indexed root);

    function setHeader(uint256 slot, bytes32 headerRoot) external {
        headers[slot] = headerRoot;
        // NOTE that the stateRoot emitted here is not the same as the header root
        // in the real LightClient
        head = slot;
        emit HeadUpdate(slot, headerRoot);
    }

    function setExecutionRoot(uint256 slot, bytes32 executionRoot) external {
        // NOTE that the root emitted here is not the same as the header root
        // in the real LightClient
        executionStateRoots[slot] = executionRoot;
        head = slot;
        emit HeadUpdate(slot, executionRoot);
    }
}
