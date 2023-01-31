pragma solidity 0.8.14;
pragma experimental ABIEncoderV2;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../../src/amb/SourceAMB.sol";
import './Counter.sol';

contract CounterTest is Test {
    SourceAMB sourceAMB;
    Counter counter;

    function setUp() public {
        sourceAMB = new SourceAMB();
        counter = new Counter(sourceAMB, address(0), address(0));
        counter.setOtherSideCounterMap(uint16(100), 0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990);
    }

    function testIncrement() public {
        counter.increment(100);
    }

    function testIncrementViaLog() public {
        counter.incrementViaLog(100);
    }
}
