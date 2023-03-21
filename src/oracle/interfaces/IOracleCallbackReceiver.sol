pragma solidity ^0.8.16;

interface IOracleCallbackReceiver {
    function handleOracleResponse(uint256 nonce, bytes memory responseData, bool responseSuccess)
        external;
}
