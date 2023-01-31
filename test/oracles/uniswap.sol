import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import "@uniswap/v3-core/contracts/libraries/FullMath.sol";

import "src/amb/SourceAMB.sol";
import "forge-std/console.sol";

contract CrossChainTWAPBroadcast {
    SourceAMB sourceAMB;
    mapping(uint16 => address) public deliveringContracts;

    event Broadcast(
        uint16 indexed chainId, 
        address poolAddress, 
        uint32 twapInterval, 
        uint256 timestamp, 
        uint256 price 
    );


    constructor(SourceAMB _sourceAMB) {
        sourceAMB = _sourceAMB;
    }

    function setDeliveringContract(uint16 chainId, address _contract) external {
        deliveringContracts[chainId] = _contract;
    }

    // Code taken from https://chaoslabs.xyz/posts/chaos-labs-uniswap-v3-twap-deep-dive-pt-1
    function getPrice(address poolAddress, uint32 twapInterval) public view returns (uint256 priceX96) {
        require(twapInterval > 0);
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapInterval;
        secondsAgos[1] = 0;
        (int56[] memory tickCumulatives, ) = IUniswapV3Pool(poolAddress).observe(secondsAgos);
        console.logInt(tickCumulatives[0]);
        console.logInt(tickCumulatives[1]);
        uint32 numerator;
        int24 tick;
        // unchecked { uint32 numerator = ; }
        unchecked { int24 tick = int24( int32( uint32(uint56(tickCumulatives[1] - tickCumulatives[0]) / twapInterval))); }
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
            tick
        );
        return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
    }

    function broadcastPrice(uint16 chainId, address poolAddress, uint32 twapInterval) external returns (uint256 priceX96) {
        require(deliveringContracts[chainId] != address(0), "TWAP Broadcast: otherSideContract not set");
        uint256 priceX96 = getPrice(poolAddress, twapInterval);
        bytes memory data = abi.encode(poolAddress, twapInterval, block.timestamp, priceX96);
        sourceAMB.send(deliveringContracts[chainId], chainId, 100000, data);
        emit Broadcast(chainId, poolAddress, twapInterval, block.timestamp, priceX96);
        return priceX96;
    }

}

contract CrossChainTWAPReciever {
    address broadcaster;
    address deliveringAMB;

    mapping(bytes32 => uint256) public priceMap;
    mapping(bytes32 => uint256) public timestampMap;

    constructor(address _broadcaster, address _deliveringAMB) {
        broadcaster = _broadcaster;
        deliveringAMB = _deliveringAMB;
    }

    function receiveSuccinct(address sender, bytes memory data) external {
        require(msg.sender == deliveringAMB);
        require(sender == broadcaster);
        (address poolAddress, uint32 twapInterval, uint256 timestamp, uint256 priceX96) = abi.decode(data, (address, uint32, uint256, uint256));
        // We only accept incrementing timestamps per (poolAddress, twapInterval) pair, for simplicity
        bytes32 key = keccak256(abi.encode(poolAddress, twapInterval));
        require(timestamp > timestampMap[key]);
        priceMap[key] = priceX96;
        timestampMap[key] = timestamp;
    }

    function getLatestPrice(address poolAddress, uint32 twapInterval) public view returns (uint256 priceX96, uint256 timestamp) {
        bytes32 key = keccak256(abi.encode(poolAddress, twapInterval));
        priceX96 = priceMap[key];
        timestamp = timestampMap[key];
    }
}