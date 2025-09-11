// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/DepositContract.sol";
import "contracts/LendingProtocol.sol";

/**
* @dev AutoCompoundVault: a simplified ERC-4626-like vault for wMTN that issues aMTN shares.
* It can instruct DepositContract to send MTN to LendingProtocol (deploy liquidity) and harvest interest.
*/
contract AutoCompoundVault is ERC20, Ownable (msg.sender) {
using SafeERC20 for IERC20;


IERC20 public immutable asset; // wMTN
DepositContract public immutable depositContract;
LendingProtocol public lendingProtocol;


// total underlying assets backing the vault (in wMTN terms)
// For simplicity, we track assets as: wMTN held by vault + equivalent value of MTN deployed in lending (we'll track in MTN)


event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
event Withdraw(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
event Harvest(uint256 amountHarvested);


constructor(IERC20 _asset, DepositContract _depositContract) ERC20("Autocompounding Metana", "aMTN") {
asset = _asset;
depositContract = _depositContract;
}

modifier onlyDepositContract() {
require(msg.sender == address(depositContract), "only deposit contract");
_;
}


// DF-7: Accept deposits of wMTN and mint proportional aMTN shares.
function deposit(uint256 assets) external returns (uint256 shares) {
require(assets > 0, "zero");
uint256 _totalAssets = totalAssets();
uint256 _totalSupply = totalSupply();
// if first deposit, 1:1
if (_totalSupply == 0 || _totalAssets == 0) {
shares = assets;
} else {
shares = (assets * _totalSupply) / _totalAssets;
}


asset.safeTransferFrom(msg.sender, address(this), assets);
_mint(msg.sender, shares);


emit Deposit(msg.sender, msg.sender, assets, shares);
}

// DF-11: Allow withdrawals of aMTN for underlying wMTN.
function withdraw(uint256 shares) external returns (uint256 assets) {
require(shares > 0, "zero");
uint256 _totalAssets = totalAssets();
uint256 _totalSupply = totalSupply();
assets = (shares * _totalAssets) / _totalSupply;


_burn(msg.sender, shares);


// ensure we have enough wMTN liquidity; if not, we could pull from depositContract or lending
uint256 available = asset.balanceOf(address(this));
if (assets > available) {
uint256 need = assets - available;
// ask depositContract to pull streamed rewards or redeem
// For simplicity, try to pull streamed rewards
depositContract.pullStreamedRewards(address(this), need);
// if still insufficient, revert (in production, we'd redeem from lending)
require(asset.balanceOf(address(this)) >= assets, "insufficient liquidity");
}


asset.safeTransfer(msg.sender, assets);


emit Withdraw(msg.sender, msg.sender, assets, shares);
}


// DF-9 & DF-10: Periodically harvest yield generated from underlying assets.
// Vault harvests interest from lendingProtocol in MTN and then sends it to depositContract to be converted to wMTN
function harvest() external {
require(address(lendingProtocol) != address(0), "no lending set");
// harvest interest in MTN
uint256 harvested = lendingProtocol.harvestInterest();
if (harvested == 0) return;


// For simplicity, we will send the harvested MTN back to depositContract so it can be streamed/minted
// Approve depositContract to pull and call syncRewards or send directly
IERC20(address(depositContract.mtn())).safeTransfer(address(depositContract), harvested);
// We can trigger syncRewards by calling syncRewards on depositContract (only owner can call syncRewards in our design),
// so instead, we call a dedicated function on depositContract to handle incoming harvested funds. For now, owner must call syncRewards externally.


emit Harvest(harvested);
}


// DF-16: Provide yield information to the vault for harvesting.
// Allow owner to set lending protocol address
function setLendingProtocol(LendingProtocol _lp) external onlyOwner {
lendingProtocol = _lp;
}


// DF-8: Calculate a user's proportional share of total assets.
// totalAssets is measured in wMTN units. We consider: vault wMTN balance + deposited wMTN equivalents from depositContract's rewards (simplified)
function totalAssets() public view returns (uint256) {
// in a full implementation we'd convert MTN held in lending to equivalent wMTN amount.
// For simplicity, we consider only wMTN balance held by vault.
return asset.balanceOf(address(this));
}

// Callbacks used by DepositContract
function onDeposit(address user, uint256 amount) external {
// optional hook: currently does nothing. Could auto-migrate deposited wMTN into vault strategy.
// Protected so only DepositContract can call it
require(msg.sender == address(depositContract), "only deposit contract");
}


function onRewardSynced(uint256 amount) external {
// Called when deposit contract syncs rewards. Could be used to auto-harvest or rebalance.
require(msg.sender == address(depositContract), "only deposit contract");
}
}
