pragma solidity 0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {MockTelepathy} from "src/amb/mocks/MockTelepathy.sol";

import "./UniswapExample.sol";

contract UniswapTWAPTest is Test {
    uint32 constant SOURCE_CHAIN = 1;
    uint32 constant DEST_CHAIN = 100;

    bool skipTest;

    MockTelepathy router;
    MockTelepathy receiver;
    CrossChainTWAPRoute twapSender;
    CrossChainTWAPReceiver twapReceiver;

    function setUp() public {
        try vm.envString("MAINNET_RPC_URL") returns (string memory MAINNET_RPC_URL) {
            uint256 forkId = vm.createSelectFork(MAINNET_RPC_URL);
            if (forkId == 0) {
                console.log("Forking mainnet failed, skipping test");
                skipTest = true;
            }
        } catch {
            console.log("MAINNET_RPC_URL not set, skipping test");
            skipTest = true;
        }

        router = new MockTelepathy(SOURCE_CHAIN);
        receiver = new MockTelepathy(DEST_CHAIN);
        router.addTelepathyReceiver(DEST_CHAIN, receiver);
        twapSender = new CrossChainTWAPRoute(address(router));
        twapReceiver =
            new CrossChainTWAPReceiver(SOURCE_CHAIN, address(twapSender), address(receiver));
        twapSender.setDeliveringContract(uint32(DEST_CHAIN), address(twapReceiver));
    }

    function test_UniswapBroadcast() public {
        if (skipTest) return;

        uint256 timestamp = 1641070800;
        vm.warp(timestamp);
        // ETH/USDC 0.3% pool on Eth mainnet
        address poolAddress = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
        uint32 twapInterval = 60; // 60 seconds
        uint256 price = twapSender.routePrice(DEST_CHAIN, poolAddress, twapInterval);
        router.executeNextMessage();
        (uint256 price_, uint256 timestamp_) =
            twapReceiver.getLatestPrice(poolAddress, twapInterval);
        require(price_ == price);
        require(timestamp_ == timestamp);
    }
}
