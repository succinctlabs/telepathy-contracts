import "openzeppelin-contracts/token/ERC20/ERC20.sol";

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IERC20Ownable is IERC20 {
	function mint(address to, uint256 amount) external;
}

contract Succincts is ERC20Burnable, Ownable, IERC20Ownable {
    // This is the 
    constructor() ERC20("Succincts", "SUCC") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

contract InfiniteMintSuccincts is ERC20 {
	constructor(uint256 initialSupply, address minter) ERC20("Succincts", "SUCC") {
		_mint(minter, initialSupply);
	}

	function mint(address to, uint256 amount) public {
		_mint(to, amount);
	}
}
