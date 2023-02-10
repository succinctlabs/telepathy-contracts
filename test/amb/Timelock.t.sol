pragma solidity 0.8.14;
pragma experimental ABIEncoderV2;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";
import {Timelock} from "src/libraries/Timelock.sol";

contract Simple {
    uint256 value;

    function setValue(uint256 _value) public {
        value = _value;
    }
}

struct Parameters {
    address target;
    uint256 value;
    bytes data;
    bytes32 predecessor;
    bytes32 salt;
    uint256 delay;
}

contract TimelockTest is Test {
    bytes32 SALT = 0x025e7b0be353a74631ad648c667493c0e1cd31caa4cc2d3520fdc171ea0cc726;
    uint256 MIN_DELAY = 60 * 24 * 24;
    address bob = payable(address(uint160(uint256(keccak256(abi.encodePacked("bob"))))));
    Timelock timelock;

    event CallScheduled(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        uint256 delay
    );

    function setUp() public {
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = bob;
        executors[0] = bob;

        vm.deal(bob, 100);

        timelock = new Timelock(
            MIN_DELAY,
            proposers,
            executors,
            address(0)
        );
    }

    function testCanPropose() public {
        Simple sample = new Simple();

        Parameters memory parameters = Parameters(
            address(sample),
            0,
            abi.encodeWithSelector(Simple.setValue.selector, 1),
            bytes32(0),
            SALT,
            MIN_DELAY
        );

        bytes32 id = keccak256(
            abi.encode(
                parameters.target,
                parameters.value,
                parameters.data,
                parameters.predecessor,
                parameters.salt
            )
        );

        vm.expectEmit(true, true, false, true, address(timelock));
        emit CallScheduled(
            id,
            0,
            parameters.target,
            parameters.value,
            parameters.data,
            parameters.predecessor,
            parameters.delay
            );

        vm.prank(bob);
        timelock.schedule(
            parameters.target,
            parameters.value,
            parameters.data,
            parameters.predecessor,
            parameters.salt,
            parameters.delay
        );
    }
}
