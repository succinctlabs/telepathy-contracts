pragma solidity 0.8.14;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {MockTelepathy} from "src/amb/mocks/MockAMB.sol";

import "./uniswap.sol";

contract UniswapTWAPTest is Test {
    uint16 constant SOURCE_CHAIN = 1;
    uint16 constant DEST_CHAIN = 100;

    MockTelepathy broadcaster;
    MockTelepathy receiver;
    CrossChainTWAPBroadcast twapSender;
    CrossChainTWAPReceiver twapReceiver;

    function setUp() public {
        string memory MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
        vm.createSelectFork(MAINNET_RPC_URL);
        broadcaster = new MockTelepathy(SOURCE_CHAIN);
        receiver = new MockTelepathy(DEST_CHAIN);
        broadcaster.addTelepathyReceiver(DEST_CHAIN, receiver);
        twapSender = new CrossChainTWAPBroadcast(address(broadcaster));
        twapReceiver =
            new CrossChainTWAPReceiver(SOURCE_CHAIN, address(twapSender), address(receiver));
        twapSender.setDeliveringContract(uint16(DEST_CHAIN), address(twapReceiver));
    }

    function testUniswapBroadcast() public {
        uint256 timestamp = 1641070800;
        vm.warp(timestamp);
        // ETH/USDC 0.3% pool on Eth mainnet
        address poolAddress = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
        uint32 twapInterval = 60; // 60 seconds
        uint256 price = twapSender.broadcastPrice(DEST_CHAIN, poolAddress, twapInterval);
        broadcaster.executeNextMessage();
        (uint256 price_, uint256 timestamp_) =
            twapReceiver.getLatestPrice(poolAddress, twapInterval);
        require(price_ == price);
        require(timestamp_ == timestamp);
    }
}
