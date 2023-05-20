pragma solidity 0.8.16;

import {TargetAMB} from "src/amb/TargetAMB.sol";
import {TelepathyStorage} from "src/amb/TelepathyStorage.sol";
import {TelepathyAccess} from "src/amb/TelepathyAccess.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title DrillTelepathy
/// @dev This contract is used solely for testing purposes and should not be used by production contracts.
contract DrillTelepathyRouter is TelepathyStorage, TargetAMB {
    address guardian;
    address emitter;

    constructor(address _guardian, address _emitter) {
        guardian = _guardian;
        emitter = _emitter;
    }

    function freezeAll() external view {
        require(msg.sender == guardian);
    }

    function emitFakeExecutedMessageEvent(
        uint16 _chainId,
        uint64 _nonce,
        bytes32 _msgHash,
        bytes memory _message,
        bool _status
    ) external {
        require(msg.sender == emitter);
        emit ExecutedMessage(_chainId, _nonce, _msgHash, _message, _status);
    }
}
