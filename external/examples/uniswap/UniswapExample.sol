pragma solidity 0.8.16;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import "@uniswap/v3-core/contracts/libraries/FullMath.sol";

import {ITelepathyRouterV2} from "src/amb-v2/interfaces/ITelepathy.sol";
import {TelepathyHandlerV2} from "src/amb-v2/interfaces/TelepathyHandler.sol";

contract CrossChainTWAPRoute {
    ITelepathyRouter router;
    mapping(uint32 => address) public deliveringContracts;

    event Route(
        uint32 indexed chainId,
        address poolAddress,
        uint32 twapInterval,
        uint256 timestamp,
        uint256 price
    );

    constructor(address _router) {
        router = ITelepathyRouterV2(_router);
    }

    function setDeliveringContract(uint32 chainId, address _contract) external {
        deliveringContracts[chainId] = _contract;
    }

    // Code taken from https://chaoslabs.xyz/posts/chaos-labs-uniswap-v3-twap-deep-dive-pt-1
    function getPrice(address poolAddress, uint32 twapInterval)
        public
        view
        returns (uint256 priceX96)
    {
        require(twapInterval > 0);
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapInterval;
        secondsAgos[1] = 0;
        (int56[] memory tickCumulatives,) = IUniswapV3Pool(poolAddress).observe(secondsAgos);
        // uint32 numerator;
        int24 tick;
        unchecked {
            tick =
                int24(int32(uint32(uint56(tickCumulatives[1] - tickCumulatives[0]) / twapInterval)));
        }
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
        return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
    }

    function routePrice(uint32 chainId, address poolAddress, uint32 twapInterval)
        external
        payable
        returns (uint256 priceX96)
    {
        require(deliveringContracts[chainId] != address(0), "TWAP Route: otherSideContract not set");
        priceX96 = getPrice(poolAddress, twapInterval);
        bytes memory data = abi.encode(poolAddress, twapInterval, block.timestamp, priceX96);
        router.send{value: msg.value}(chainId, deliveringContracts[chainId], data);
        emit Route(chainId, poolAddress, twapInterval, block.timestamp, priceX96);
    }
}

contract CrossChainTWAPReceiver is TelepathyHandlerV2 {
    uint32 srcChainId;
    address sourceAddress;

    mapping(bytes32 => uint256) public priceMap;
    mapping(bytes32 => uint256) public timestampMap;

    constructor(uint32 _srcChainId, address _sourceAddress, address _telepathyReceiver)
        TelepathyHandlerV2(_telepathyReceiver)
    {
        srcChainId = _srcChainId;
        sourceAddress = _sourceAddress;
    }

    function handleTelepathyImpl(uint32 _srcChainId, address sender, bytes memory data)
        internal
        override
    {
        require(_srcChainId == srcChainId);
        require(sender == sourceAddress);
        (address poolAddress, uint32 twapInterval, uint256 timestamp, uint256 priceX96) =
            abi.decode(data, (address, uint32, uint256, uint256));
        // We only accept incrementing timestamps per (poolAddress, twapInterval) pair, for simplicity
        bytes32 key = keccak256(abi.encode(poolAddress, twapInterval));
        require(timestamp > timestampMap[key]);
        priceMap[key] = priceX96;
        timestampMap[key] = timestamp;
    }

    function getLatestPrice(address poolAddress, uint32 twapInterval)
        public
        view
        returns (uint256 priceX96, uint256 timestamp)
    {
        bytes32 key = keccak256(abi.encode(poolAddress, twapInterval));
        priceX96 = priceMap[key];
        timestamp = timestampMap[key];
    }
}
