pragma solidity ^0.8.16;

import {ITelepathyRouter} from "src/amb/interfaces/ITelepathy.sol";
import {RequestData} from "src/oracle/TelepathyOracle.sol";

contract TelepathyOracleFulfiller {
    ITelepathyRouter telepathyRouter;

    constructor(address _telepathyRouter) {
        telepathyRouter = ITelepathyRouter(_telepathyRouter);
    }

    function fulfillCrossChainRequest(
        uint32 _oracleChain,
        address _oracleAddress,
        RequestData calldata _requestData
    ) external {
        bool success = false;
        bytes memory resultData;
        if (_requestData.targetContract.code.length != 0) {
            (success, resultData) = _requestData.targetContract.call(_requestData.targetCalldata);
        }
        bytes32 requestHash = keccak256(abi.encode(_requestData));
        bytes memory data = abi.encode(
            _requestData.nonce, requestHash, _requestData.callbackContract, resultData, success
        );
        telepathyRouter.send(_oracleChain, _oracleAddress, data);
    }
}
