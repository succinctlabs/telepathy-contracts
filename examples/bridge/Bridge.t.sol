// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/console.sol";
import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "forge-std/Test.sol";

import "openzeppelin-contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

import "src/amb/mocks/MockTelepathy.sol";

import "./Bridge.sol";
import "./Tokens.sol";

contract BridgeTest is Test {
    uint32 constant SOURCE_CHAIN = 1;
    uint32 constant DEST_CHAIN = 2;

    MockTelepathy broadcaster;
    MockTelepathy receiver;
    ERC20 depositToken;
    Deposit deposit;
    Withdraw withdraw;

    function setUp() public {
        broadcaster = new MockTelepathy(SOURCE_CHAIN);
        receiver = new MockTelepathy(DEST_CHAIN);
        broadcaster.addTelepathyReceiver(DEST_CHAIN, receiver);
        // Make a mock ERC-20 for testing
        depositToken = new ERC20PresetFixedSupply("GigaBrainToken", "GBT", 1000000, address(this));
        deposit = new Deposit(address(broadcaster), address(depositToken));
        withdraw = new Withdraw(address(deposit), address(receiver), SOURCE_CHAIN);
        deposit.setWithdraw(address(withdraw));
    }

    function _deposit(uint256 amount) internal {
        depositToken.approve(address(deposit), amount);
        address recipient = makeAddr("recipient");
        deposit.deposit{value: deposit.FEE()}(recipient, amount, address(depositToken), DEST_CHAIN);
    }

    function testDeposit() public {
        _deposit(5);
        require(depositToken.balanceOf(address(deposit)) == 5);
    }

    function testDepositAndWithdraw() public {
        _deposit(5);
        require(depositToken.balanceOf(address(deposit)) == 5);
        require(withdraw.token().balanceOf(makeAddr("recipient")) == 0);
        broadcaster.executeNextMessage();
        require(withdraw.token().balanceOf(makeAddr("recipient")) == 5);
    }

    function testDepositRequiresFee() public {
        // expect a revert here
        depositToken.approve(address(deposit), 5);
        address recipient = makeAddr("recipient");
        vm.expectRevert("Not enough fee");
        deposit.deposit(recipient, 5, address(depositToken), 2);
    }

    function testClaimFees() public {
        _deposit(5);
        // We must transfer the deposit contract to an EOA to claim fees since
        // by default it owned by the BridgeTest contract, which is not payable
        address eoa = makeAddr("eoa");
        deposit.transferOwnership(eoa);
        vm.prank(eoa);
        deposit.claimFees();
        assertEq(eoa.balance, deposit.FEE());
    }

    function testClaimFeesToAddress() public {
        _deposit(5);
        deposit.claimFees(makeAddr("anotherEOA"));
        assertEq(makeAddr("anotherEOA").balance, deposit.FEE());
    }

    function testOnlyOwnerClaimFees() public {
        vm.prank(makeAddr("anotherEOA"));
        vm.expectRevert("Ownable: caller is not the owner");
        deposit.claimFees();
    }
}
