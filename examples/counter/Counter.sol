pragma solidity 0.8.14;

import {ITelepathyBroadcaster} from "src/amb/interfaces/ITelepathy.sol";
import {TelepathyHandler} from "src/amb/interfaces/TelepathyHandler.sol";

contract Counter is TelepathyHandler {
    // We put together the sending the recieving counters instead of
    // separating them out for ease of use.

    uint256 public nonce;
    ITelepathyBroadcaster broadcaster;
    mapping(uint16 => address) public otherSideCounterMap;
    address otherSideCounter;

    event Incremented(uint256 indexed nonce, uint16 indexed chainId);

    constructor(ITelepathyBroadcaster _broadcaster, address _counter, address _telepathyReceiver)
        TelepathyHandler(_telepathyReceiver)
    {
        // Only relevant for controlling counter
        broadcaster = _broadcaster;
        // This is only relevant for the recieving counter
        otherSideCounter = _counter;
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

    // Receiving counter functions

    function setOtherSideCounter(address _counter) external {
        otherSideCounter = _counter;
    }

    /// @notice handleTelepathy is called by the Telepathy Receiver when a message is executed
    /// @dev We do not enforce any checks on the `_srcChainId` since we want to allow the counter
    /// to receive messages from any chain
    function handleTelepathy(uint16, address _senderAddress, bytes memory _data)
        internal
        override
    {
        require(_senderAddress == otherSideCounter);
        (uint256 _nonce) = abi.decode(_data, (uint256));
        nonce = _nonce;
        emit Incremented(nonce, uint16(block.chainid));
    }
}
