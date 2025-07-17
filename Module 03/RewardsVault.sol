pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./CommunityToken.sol";

contract RewardsVault is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant AUDITOR_ROLE = PAUSER_ROLE;

    uint256 public constant RATE = 1e18 / 0.01 ether;

    CommunityToken public immutable token;
    address public foundationWallet;

    error ZeroAddress();
    error TransferFailed();
    error InvalidAmount();

    event Donation(address indexed donor, uint256 amount);
    event Withdrawal(uint256 amount);

    constructor(CommunityToken _token, address admin, address _foundationWallet) {
        if (address(_token) == address(0) || admin == address(0) || _foundationWallet == address(0)) 
            revert ZeroAddress();
        
        token = _token;
        foundationWallet = _foundationWallet;
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(token.MINTER_ROLE(), address(this));
    }

    function donate() external payable nonReentrant whenNotPaused {
        if( msg.value == 0) revert InvalidAmount();
        uint256 tokensToMint = (msg.value * RATE) / 1e18;
        token.mint(msg.sender, tokensToMint);
        emit Donation(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external nonReentrant onlyRole(TREASURER_ROLE) whenNotPaused {
        if (amount == 0 || amount > address(this).balance) revert InvalidAmount();
        (bool success, ) = foundationWallet.call{value: amount}("");
        if (!success) revert TransferFailed();
        emit Withdrawal(amount);
    }

    function setFoundationWallet(address newWallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newWallet == address(0)) revert ZeroAddress();
        foundationWallet = newWallet;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    receive() external payable {
        revert();
    }

    fallback() external payable {
        revert();
    }
}