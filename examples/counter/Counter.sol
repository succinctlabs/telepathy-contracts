pragma solidity 0.8.14;

import {ITelepathyHandler, ITelepathyBroadcaster} from "src/amb/interfaces/ITelepathy.sol";

contract Counter is ITelepathyHandler {
    // We put together the sending the recieving counters instead of
    // separating them out for ease of use.

    uint256 public nonce;
    ITelepathyBroadcaster broadcaster;
    mapping(uint16 => address) public otherSideCounterMap;
    address otherSideCounter;
    address targetAMB;

    event Incremented(uint256 indexed nonce, uint16 indexed chainId);

    constructor(ITelepathyBroadcaster _broadcaster, address _counter, address _targetAMB) {
        // Only relevant for controlling counter
        broadcaster = _broadcaster;
        // This is only relevant for the recieving counter
        otherSideCounter = _counter;
        targetAMB = _targetAMB;
        nonce = 1;
    }

    // Controlling counter functions

    // Relevant for controlling counter
    function setSourceAMB(ITelepathyBroadcaster _broadcaster) external {
        broadcaster = _broadcaster;
    }

    // Relevant for controlling counter
    function setOtherSideCounterMap(uint16 chainId, address counter) external {
        otherSideCounterMap[chainId] = counter;
    }

    function increment(uint16 chainId) external {
        nonce++;
        require(otherSideCounterMap[chainId] != address(0), "Counter: otherSideCounter not set");
        broadcaster.send(chainId, otherSideCounterMap[chainId], abi.encode(nonce));
        emit Incremented(nonce, chainId);
    }

    function incrementViaLog(uint16 chainId) external {
        nonce++;
        require(otherSideCounterMap[chainId] != address(0), "Counter: otherSideCounter not set");
        broadcaster.sendViaLog(chainId, otherSideCounterMap[chainId], abi.encode(nonce));
        emit Incremented(nonce, chainId);
    }

    // Recieving counter functions

    // Relevant for recieving counter
    function setTargetAMB(address _targetAMB) external {
        targetAMB = _targetAMB;
    }

    function setOtherSideCounter(address _counter) external {
        otherSideCounter = _counter;
    }

    function handleTelepathy(uint16, address _senderAddress, bytes memory _data) external {
        require(msg.sender == targetAMB);
        require(_senderAddress == otherSideCounter);
        (uint256 _nonce) = abi.decode(_data, (uint256));
        nonce = _nonce;
        emit Incremented(nonce, uint16(block.chainid));
    }
}
