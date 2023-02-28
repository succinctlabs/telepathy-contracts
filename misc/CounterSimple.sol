pragma solidity 0.8.16;

// To build this, run: FOUNDRY_PROFILE=misc forge build

contract CounterSimple {
    uint256 public counter = 0;

    event Incremented(uint256 value, address indexed sender);

    function increment() public {
        counter++;
        emit Incremented(counter, msg.sender);
    }
}
