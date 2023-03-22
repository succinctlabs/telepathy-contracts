// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Message} from "src/amb/interfaces/ITelepathy.sol";
import {MockTelepathy} from "src/amb/mocks/MockTelepathy.sol";
import {TelepathyOracle, RequestStatus, RequestData} from "src/oracle/TelepathyOracle.sol";
import {TelepathyHandler} from "src/amb/interfaces/TelepathyHandler.sol";
import {TelepathyOracleFulfiller} from "src/oracle/TelepathyOracleFulfiller.sol";
import {IOracleCallbackReceiver} from "src/oracle/interfaces/IOracleCallbackReceiver.sol";

contract MockMainnetData {
    uint256 val = block.timestamp;

    function get() public view returns (uint256) {
        return val;
    }

    function hashString(string memory str) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(str));
    }
}

contract MockReceiver is IOracleCallbackReceiver {
    uint256 public result;

    function handleOracleResponse(uint256, bytes memory responseData, bool) external override {
        result = abi.decode(responseData, (uint256));
    }
}

contract TelepathyOracleTest is Test {
    event CrossChainRequestSent(
        uint256 indexed nonce,
        address targetContract,
        bytes targetCalldata,
        address callbackContract
    );

    MockTelepathy telepathyRouterSrc;
    MockTelepathy telepathyRouterDst;
    TelepathyOracleFulfiller fulfiller;
    TelepathyOracle oracle;

    uint32 ORACLE_CHAIN = 137;
    uint32 FULFILLER_CHAIN = 1;

    function makeRequest(
        address targetContract,
        bytes memory targetCalldata,
        address callbackContract
    ) internal returns (RequestData memory requestData, bytes32 requestHash) {
        uint256 nonce = oracle.requestCrossChain(targetContract, targetCalldata, callbackContract);
        requestData = RequestData(nonce, targetContract, targetCalldata, callbackContract);
        requestHash = keccak256(abi.encode(requestData));
    }

    function setUp() public {
        telepathyRouterSrc = new MockTelepathy(FULFILLER_CHAIN);
        telepathyRouterDst = new MockTelepathy(ORACLE_CHAIN);
        telepathyRouterSrc.addTelepathyReceiver(ORACLE_CHAIN, telepathyRouterDst);
        fulfiller = new TelepathyOracleFulfiller(address(telepathyRouterSrc));
        oracle = new TelepathyOracle{salt: 0}(
            FULFILLER_CHAIN,
            address(telepathyRouterDst),
            address(fulfiller)
        );
    }

    function testSimple() public {
        MockMainnetData mockMainnetData = new MockMainnetData();
        MockReceiver receiver = new MockReceiver();
        assertEq(receiver.result(), 0);
        address targetContract = address(mockMainnetData);
        bytes memory targetCalldata = abi.encodeWithSelector(MockMainnetData.get.selector);
        address callbackContract = address(receiver);

        vm.expectEmit(true, true, true, false);
        emit CrossChainRequestSent(1, targetContract, targetCalldata, callbackContract);
        (RequestData memory requestData, bytes32 requestHash) =
            makeRequest(targetContract, targetCalldata, callbackContract);
        assertEq(requestData.nonce, 1);
        assertTrue(oracle.requests(requestHash) == RequestStatus.PENDING);

        fulfiller.fulfillCrossChainRequest(ORACLE_CHAIN, address(oracle), requestData);

        telepathyRouterSrc.executeNextMessage();

        assertEq(receiver.result(), mockMainnetData.get());
    }

    function testRevertNotFromRouter() public {
        vm.expectRevert(
            abi.encodeWithSelector(TelepathyHandler.NotFromTelepathyRouter.selector, address(this))
        );
        oracle.handleTelepathy(FULFILLER_CHAIN, address(fulfiller), "");
    }

    function testRevertWrongChainId() public {
        vm.prank(address(telepathyRouterDst));
        vm.expectRevert(abi.encodeWithSelector(TelepathyOracle.InvalidChainId.selector, 12345));
        oracle.handleTelepathy(12345, address(fulfiller), "");
    }

    function testRevertNotFromFulfiller() public {
        vm.prank(address(telepathyRouterDst));
        vm.expectRevert(
            abi.encodeWithSelector(TelepathyOracle.NotFulfiller.selector, address(this))
        );
        oracle.handleTelepathy(FULFILLER_CHAIN, address(this), "");
    }

    function testRevertReplayResponse() public {
        MockMainnetData mockMainnetData = new MockMainnetData();
        MockReceiver receiver = new MockReceiver();
        assertEq(receiver.result(), 0);
        address targetContract = address(mockMainnetData);
        bytes memory targetCalldata = abi.encodeWithSelector(MockMainnetData.get.selector);
        address callbackContract = address(receiver);

        (RequestData memory requestData, bytes32 requestHash) =
            makeRequest(targetContract, targetCalldata, callbackContract);

        fulfiller.fulfillCrossChainRequest(ORACLE_CHAIN, address(oracle), requestData);
        (,, uint32 sourceChainId, address senderAddress,,, bytes memory data) =
            telepathyRouterSrc.sentMessages(1);
        vm.prank(address(telepathyRouterDst));
        oracle.handleTelepathy(sourceChainId, senderAddress, data);

        fulfiller.fulfillCrossChainRequest(ORACLE_CHAIN, address(oracle), requestData);
        vm.prank(address(telepathyRouterDst));
        vm.expectRevert(
            abi.encodeWithSelector(TelepathyOracle.RequestNotPending.selector, requestHash)
        );
        oracle.handleTelepathy(sourceChainId, senderAddress, data);
    }

    function testRevertIncorrectResponseData() public {
        MockMainnetData mockMainnetData = new MockMainnetData();
        MockReceiver receiver = new MockReceiver();
        assertEq(receiver.result(), 0);
        address targetContract = address(mockMainnetData);
        bytes memory targetCalldata =
            abi.encodeWithSelector(MockMainnetData.hashString.selector, "hello world");
        address callbackContract = address(receiver);

        bytes memory fakeTargetCalldata =
            abi.encodeWithSelector(MockMainnetData.hashString.selector, "goodbye world");

        (RequestData memory realRequestData,) =
            makeRequest(targetContract, targetCalldata, callbackContract);

        RequestData memory fakeRequestData = RequestData(
            realRequestData.nonce,
            realRequestData.targetContract,
            fakeTargetCalldata,
            realRequestData.callbackContract
        );

        fulfiller.fulfillCrossChainRequest(ORACLE_CHAIN, address(oracle), fakeRequestData);
        (,, uint32 sourceChainId, address senderAddress,,, bytes memory data) =
            telepathyRouterSrc.sentMessages(1);

        bytes32 fakeRequestHash = keccak256(abi.encode(fakeRequestData));

        vm.prank(address(telepathyRouterDst));
        vm.expectRevert(
            abi.encodeWithSelector(TelepathyOracle.RequestNotPending.selector, fakeRequestHash)
        );
        oracle.handleTelepathy(sourceChainId, senderAddress, data);
    }

    function testNonContractTarget() public {
        MockReceiver receiver = new MockReceiver();
        assertEq(receiver.result(), 0);
        address targetContract = address(0);
        bytes memory targetCalldata = "";
        address callbackContract = address(receiver);

        (RequestData memory requestData,) =
            makeRequest(targetContract, targetCalldata, callbackContract);

        fulfiller.fulfillCrossChainRequest(ORACLE_CHAIN, address(oracle), requestData);
        (,,,,,, bytes memory responseData) = telepathyRouterSrc.sentMessages(1);
        (,,,, bool responseSuccess) =
            abi.decode(responseData, (uint256, bytes32, address, bytes, bool));

        assertFalse(responseSuccess);
    }
}
