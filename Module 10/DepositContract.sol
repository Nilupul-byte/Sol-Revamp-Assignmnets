// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/WrappedMetana.sol";

/**
* @dev DepositContract accepts MTN and mints wMTN 1:1.
* It can sync rewards (added MTN) to be streamed over time.
* Vaults or other privileged contracts can be registered.
*/
contract DepositContract is Ownable (msg.sender) {
using SafeERC20 for IERC20;


IERC20 public immutable mtn;
WrappedMetana public immutable wMtn;


// Address of the autocompound vault that will be notified
address public vault;


uint256 public totalMtnDeposited;
uint256 public totalWMtnMinted;


// Reward streaming variables
uint256 public rewardBalance; // MTN amount reserved for streaming
uint256 public rewardRatePerSecond; // MTN per second being streamed
uint256 public rewardPeriodFinish;
uint256 public lastUpdateTime;


event Deposited(address indexed user, uint256 amount);
event Withdrawn(address indexed user, uint256 amount);
event RewardSynced(uint256 amount, uint256 duration);
event VaultNotified(address vault, uint256 depositedAmount);


constructor(IERC20 _mtn, WrappedMetana _wMtn) {
mtn = _mtn;
wMtn = _wMtn;
}


modifier onlyVault() {
require(msg.sender == vault, "DepositContract: only vault");
_;
}


function setVault(address _vault) external onlyOwner {
vault = _vault;
}


/// DF-1: Accept deposits of MTN and mint wMTN at 1:1 ratio.
function deposit(uint256 amount) external {
require(amount > 0, "zero");
mtn.safeTransferFrom(msg.sender, address(this), amount);
wMtn.mint(msg.sender, amount);


totalMtnDeposited += amount;
totalWMtnMinted += amount;


emit Deposited(msg.sender, amount);


// DF-3: Notify the ERC-4626 vault of deposited assets (if set)
if (vault != address(0)) {
// low-level call to avoid circular dependency if vault not set up yet
(bool ok, ) = vault.call(abi.encodeWithSignature("onDeposit(address,uint256)", msg.sender, amount));
if (ok) emit VaultNotified(vault, amount);
}
}


/// Allow users to burn wMTN and withdraw MTN 1:1
function withdraw(uint256 amount) external {
require(amount > 0, "zero");
wMtn.burn(msg.sender, amount);
mtn.safeTransfer(msg.sender, amount);


totalMtnDeposited -= amount;
totalWMtnMinted -= amount;


emit Withdrawn(msg.sender, amount);
}


// DF-2: Sync newly added rewards for streaming over time.
// Owner (or keeper) can call to add reward MTN which will be streamed over `duration` seconds.
function syncRewards(uint256 amount, uint256 duration) external onlyOwner {
require(amount > 0 && duration > 0, "invalid");
// transfer MTN into this contract to be streamed
mtn.safeTransferFrom(msg.sender, address(this), amount);


// update streaming accounting
_updateReward();


// if previous period still running, add leftover
uint256 remaining = 0;
if (block.timestamp < rewardPeriodFinish) {
remaining = (rewardPeriodFinish - block.timestamp) * rewardRatePerSecond;
}


uint256 newTotal = remaining + amount;
rewardRatePerSecond = newTotal / duration;
rewardPeriodFinish = block.timestamp + duration;
lastUpdateTime = block.timestamp;
rewardBalance = newTotal;


emit RewardSynced(amount, duration);


// DF-3: optionally notify vault that rewards added
if (vault != address(0)) {
(bool ok, ) = vault.call(abi.encodeWithSignature("onRewardSynced(uint256)", amount));
// ignore failure
}
}


// internal helper to update reward accounting (reduces rewardBalance)
function _updateReward() internal {
uint256 last = lastUpdateTime == 0 ? block.timestamp : lastUpdateTime;
uint256 toTime = block.timestamp < rewardPeriodFinish ? block.timestamp : rewardPeriodFinish;
if (toTime > last) {
uint256 elapsed = toTime - last;
uint256 streamed = elapsed * rewardRatePerSecond;
if (streamed > rewardBalance) streamed = rewardBalance;
rewardBalance -= streamed;
lastUpdateTime = toTime;
// streamed MTN are considered available to the system; for simplicity they remain in this contract
}
}


// DF-4: Restrict certain functions to only be callable by the deposit contract.
// For our system, AutoCompoundVault will call `sendToLending` on this contract to move MTN into lending.


// DF-13 helper: send MTN to LendingProtocol - callable only by vault.
function sendToLending(address lendingProtocol, uint256 amount) external onlyVault {
require(amount > 0, "zero");
_updateReward();
// Transfer MTN from this deposit contract to lending protocol
IERC20(address(mtn)).safeTransfer(lendingProtocol, amount);


// extend accounting
totalMtnDeposited -= amount; // MTN is deployed off the deposit balance


// call lendingProtocol.lendFromDeposit
(bool ok, ) = lendingProtocol.call(abi.encodeWithSignature("depositFrom(address,uint256)", msg.sender, amount));
require(ok, "lend call failed");
}


// Allow vault to pull available streamed rewards (simple helper)
function pullStreamedRewards(address to, uint256 amount) external onlyVault {
_updateReward();
require(amount <= rewardBalance, "exceed rewards");
rewardBalance -= amount;
mtn.safeTransfer(to, amount);
}
}
