pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract VestingToken is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    error ZeroAddress();

    constructor(string memory name, string memory symbol, address admin, address vestingVault) 
        ERC20(name, symbol) 
    {
        if (admin == address(0) || vestingVault == address(0)) revert ZeroAddress();
        _mint(admin, 100_000_000 * 10**decimals());
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, vestingVault);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
