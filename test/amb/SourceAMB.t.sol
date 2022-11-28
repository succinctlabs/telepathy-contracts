pragma solidity 0.8.14;
pragma experimental ABIEncoderV2;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../../src/amb/SourceAMB.sol";

contract SourceAMBTest is Test {
    SourceAMB sourceAMB;

    function setUp() public {
        sourceAMB = new SourceAMB();
    }

    function testSend() public {
        sourceAMB.send(
            0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990,
            100,
            999999,
            hex"deadbeef"
        );
    }

    function testSendViaLog() public {
        sourceAMB.sendViaLog(
            0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990,
            100,
            999999,
            hex"deadbeef"
        );
    }
}
