pragma solidity 0.8.14;

// We must import X as Y so that ILightClient doesn't conflict when we try to import
// both LightClientMock and TargetAMB in the same test file.
import {ILightClient as ILightClientMock} from "src/lightclient/interfaces/ILightClient.sol";

contract LightClientMock is ILightClientMock {
    bool public consistent = true;
    uint256 public head;
    mapping(uint256 => bytes32) public headers;
    mapping(uint256 => bytes32) public executionStateRoots;
    mapping(uint256 => uint256) public timestamps;

    event HeadUpdate(uint256 indexed slot, bytes32 indexed root);

    function setHeader(uint256 slot, bytes32 headerRoot) external {
        headers[slot] = headerRoot;
        timestamps[slot] = block.timestamp;
        head = slot;
        emit HeadUpdate(slot, headerRoot);
    }

    function setExecutionRoot(uint256 slot, bytes32 executionRoot) external {
        executionStateRoots[slot] = executionRoot;
        timestamps[slot] = block.timestamp;
        head = slot;
        emit HeadUpdate(slot, executionRoot);
    }
}
