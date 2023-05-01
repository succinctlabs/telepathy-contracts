// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/console.sol";
import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "forge-std/Test.sol";

import "src/amb/mocks/MockTelepathy.sol";

import "./ExampleCounter.sol";

contract CounterTest is Test {
    uint32 constant SOURCE_CHAIN = 1;
    uint32 constant TARGET_CHAIN = 100;

    MockTelepathy router;
    MockTelepathy receiver;
    SourceCounter source;
    TargetCounter target;

    function setUp() public {
        router = new MockTelepathy(SOURCE_CHAIN);
        receiver = new MockTelepathy(TARGET_CHAIN);
        router.addTelepathyReceiver(TARGET_CHAIN, receiver);

        source = new SourceCounter(address(router), TARGET_CHAIN);
        target = new TargetCounter(address(receiver));
    }

    function test_IncrementOne() public {
        source.increment(1, address(target));
        router.executeNextMessage();
        require(target.counter() == 1);
    }

    function test_IncrementSeveral() public {
        source.increment(2, address(target));
        router.executeNextMessage();
        require(target.counter() == 2);
        source.increment(123456789, address(target));
        router.executeNextMessage();
        require(target.counter() == 123456791);
    }

    function test_IncrementOverflow() public {
        source.increment(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, address(target)
        );
        router.executeNextMessage();
        require(
            target.counter() == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        source.increment(2, address(target));
        router.executeNextMessage();
        require(target.counter() == 1);
    }
}
