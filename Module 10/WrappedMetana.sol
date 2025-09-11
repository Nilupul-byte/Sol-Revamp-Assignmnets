// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
* @dev Wrapped MTN token (wMTN) minted 1:1 by DepositContract.
*/
contract WrappedMetana is ERC20, Ownable(msg.sender) {
constructor() ERC20("Wrapped Metana", "wMTN") {}


function mint(address to, uint256 amount) external  {
_mint(to, amount);
}


function burn(address from, uint256 amount) external onlyOwner {
_burn(from, amount);
}
}
