pragma solidity 0.8.14;
pragma experimental ABIEncoderV2;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";
import "src/amb/SourceAMB.sol";
import './uniswap.sol';

contract CounterTest is Test {
    SourceAMB sourceAMB;
    CrossChainTWAPBroadcast broadcast;
    address twapReciever = 0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990;

    function setUp() public {
        string memory forkURL = "https://eth-mainnet.g.alchemy.com/v2/V3UkTYUt0iEtxdvWVRNiqEwBsQH4tuMb";
        vm.createSelectFork(forkURL);
        sourceAMB = new SourceAMB();
        broadcast = new CrossChainTWAPBroadcast(sourceAMB);
        broadcast.setDeliveringContract(uint16(100), twapReciever);
    }

    function testUniswapBroadcast() public {
        // ETH/USDC 0.3% pool on Eth mainnet
        uint256 nonce = 1;
        address msgSender = address(broadcast);
        address recipient = twapReciever;
        uint16 chainId = 100;
        uint256 gasLimit = 100000;
        uint256 timestamp = 1641070800;
        vm.warp(1641070800);

        address poolAddress = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
        uint32 twapInterval = 60; // 60 seconds
        uint256 price = broadcast.broadcastPrice(chainId, poolAddress, twapInterval);
        bytes memory msgData = abi.encode(poolAddress, twapInterval, timestamp, price);
        bytes memory message = abi.encode(nonce, msgSender, recipient, chainId, gasLimit, msgData);
        require(sourceAMB.messages(1) == keccak256(message));
    }
    
    function testUniswapBroadcastGoerli() public {
        // https://ethereum.stackexchange.com/questions/132880/where-to-find-uniswap-contract-addresses-on-goerli-testnet
        string memory forkURL = "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161";
        vm.createSelectFork(forkURL);
        sourceAMB = new SourceAMB();
        broadcast = new CrossChainTWAPBroadcast(sourceAMB);
        broadcast.setDeliveringContract(uint16(100), twapReciever);
        address poolAddress = 0x4d1892f15B03db24b55E73F9801826a56d6f0755;
        uint32 twapInterval = 60; // 60 seconds
        uint16 chainId = 100;
        uint256 price = broadcast.broadcastPrice(chainId, poolAddress, twapInterval);
        console.logUint(price);
        // This is apparently the Goerli, Eth pool
    }

    function testUniswapReceive() public {
        address mockDeliveringAMB = address(this);
        address mockBroadcaster = address(this);
        CrossChainTWAPReciever reciever = new CrossChainTWAPReciever(mockDeliveringAMB, mockBroadcaster);
        // Check that the contract can recieveSuccinct
        address poolAddress = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
        uint32 twapInterval = 60; // 60 seconds
        // Taen from line 36 msgData from above
        bytes memory data = hex"0000000000000000000000008ad599c3a0ff1de082011efddc58f1908eb6e6d8000000000000000000000000000000000000000000000000000000000000003c0000000000000000000000000000000000000000000000000000000061d0c0d00000000000000000000000000000000000000001000000000000000000000000";
        reciever.receiveSuccinct(mockBroadcaster, data);
        (uint256 price, uint256 timestamp) = reciever.getLatestPrice(poolAddress, twapInterval);
        require(price == 79228162514264337593543950336);
        require(timestamp == 1641070800);
    }
}
