pragma solidity 0.8.14;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {SourceAMB} from "src/amb/SourceAMB.sol";
import {UUPSProxy} from "src/libraries/Proxy.sol";

contract SourceAMBTest is Test {
    SourceAMB wrappedSourceAMBProxy;

    function setUp() public {
        SourceAMB sourceAMBImplementation = new SourceAMB();
        UUPSProxy proxy = new UUPSProxy(address(sourceAMBImplementation), "");

        wrappedSourceAMBProxy = SourceAMB(address(proxy));
        wrappedSourceAMBProxy.initialize(address(this));
    }

    function testSend() public {
        wrappedSourceAMBProxy.send(100, 0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990, hex"deadbeef");
    }

    function testSendViaLog() public {
        wrappedSourceAMBProxy.sendViaLog(
            100, 0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990, hex"deadbeef"
        );
    }
}
