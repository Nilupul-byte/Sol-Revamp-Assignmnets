// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;


/*
Metana DeFi System
- MetanaToken (MTN) ERC20
- WrappedMetana (wMTN) ERC20 minted 1:1 by DepositContract
- DepositContract: accepts MTN, mints wMTN, can sync rewards, and send MTN to lending
- LendingProtocol: accepts MTN, tracks lent amount and accrues interest over time
- AutoCompoundVault: ERC4626-like vault for wMTN that issues aMTN shares, harvests yield


NOTE: This is a simplified educational implementation. In production, audit, security, and gas
*/


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/**
* @dev Simple mintable ERC20 used as underlying MTN for tests and local usage.
*/
contract MetanaToken is ERC20, Ownable (msg.sender) {
constructor() ERC20("Metana", "MTN") {
_mint(msg.sender, 1_000_000 ether);
}


function mint(address to, uint256 amount) external  {
_mint(to, amount);
}
}
