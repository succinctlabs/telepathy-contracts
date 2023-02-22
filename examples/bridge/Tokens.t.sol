// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/console.sol";
import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "forge-std/Test.sol";

import "src/amb/mocks/MockAMB.sol";

import "./Tokens.sol";

contract TokenTest is Test {
    using stdStorage for StdStorage;

    function setUp() public {}

    // Test that we can mint an infinite amount of tokens
    function testInfiniteMintSuccincts() public {
        InfiniteMintSuccincts mytoken = new InfiniteMintSuccincts(0, address(this));
        uint256 balance = mytoken.balanceOf(address(this));
        assertEq(balance, 0);
        mytoken.mint(address(this), 100);
        uint256 balance2 = mytoken.balanceOf(address(this));
        assertEq(balance2, 100);
        mytoken.mint(address(this), 100);
        uint256 balance3 = mytoken.balanceOf(address(this));
        assertEq(balance3, 200);
    }
}
