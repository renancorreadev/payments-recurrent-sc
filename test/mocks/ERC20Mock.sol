// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 ether);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function faucet(uint256 amount) public {
        _mint(msg.sender, amount);
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        return true;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account);
    }
}
