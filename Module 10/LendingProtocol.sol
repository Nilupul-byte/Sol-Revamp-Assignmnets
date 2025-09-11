// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
* @dev Simple LendingProtocol that accepts MTN deposits, tracks lent amount and accrues interest over time.
* This is intentionally simplified. Borrowing/collateral logic is rudimentary and should be extended.
*/
contract LendingProtocol is Ownable (msg.sender) {
using SafeERC20 for IERC20;


IERC20 public immutable mtn;


// total principal deposited by vault(s)
uint256 public totalPrincipal;
// accrued interest not yet claimed by lenders
uint256 public accruedInterest;


// simple interest rate per year, in WAD (1e18). Example: 5% = 0.05e18
uint256 public interestRatePerYearWad;


uint256 public lastAccrualTimestamp;


event Lent(address indexed fromVault, uint256 amount);
event Repaid(address indexed borrower, uint256 amount);
event InterestAccrued(uint256 amount, uint256 timestamp);


constructor(IERC20 _mtn, uint256 _interestRatePerYearWad) {
mtn = _mtn;
interestRatePerYearWad = _interestRatePerYearWad;
lastAccrualTimestamp = block.timestamp;
}


// DF-13: Accept MTN from the vault to lend out to borrowers.
// We expect MTN to be transferred to this contract prior to calling this function.
// For convenience we allow a depositFrom which pulls from the caller.
function depositFrom(address from, uint256 amount) external {
require(amount > 0, "zero");
// In our design, DepositContract already transferred MTN to this contract, but we also support direct pull.
if (mtn.balanceOf(address(this)) < totalPrincipal + accruedInterest + amount) {
// attempt to pull
mtn.safeTransferFrom(from, address(this), amount);
}


_accrueInterest();
totalPrincipal += amount;
emit Lent(from, amount);
}


// DF-14 & DF-16: Generate interest over time for deployed MTN and provide yield information to the vault for harvesting.
// Accrue interest and increment accruedInterest.
function _accrueInterest() internal {
uint256 nowTs = block.timestamp;
if (nowTs <= lastAccrualTimestamp) return;
uint256 elapsed = nowTs - lastAccrualTimestamp;
// interest = totalPrincipal * rate * elapsed / YEAR
uint256 interest = (totalPrincipal * interestRatePerYearWad * elapsed) / (1e18 * 365 days);
if (interest > 0) {
accruedInterest += interest;
lastAccrualTimestamp = nowTs;
emit InterestAccrued(interest, nowTs);
} else {
lastAccrualTimestamp = nowTs;
}
}

// Called by vault to harvest all currently available interest
function harvestInterest() external returns (uint256) {
_accrueInterest();
uint256 toHarvest = accruedInterest;
if (toHarvest == 0) return 0;
accruedInterest = 0;
// leave principal intact; harvested interest remains in contract balance
// transfer harvested interest to caller (the vault)
mtn.safeTransfer(msg.sender, toHarvest);
return toHarvest;
}


// For testing: allow borrower to borrow and repay (very simple)
function borrow(address to, uint256 amount) external onlyOwner {
require(amount <= mtn.balanceOf(address(this)) - totalPrincipal - accruedInterest, "insufficient"
);
// owner acts as borrower in this simplified example
mtn.safeTransfer(to, amount);
}


function repay(uint256 amount) external {
require(amount > 0, "zero");
mtn.safeTransferFrom(msg.sender, address(this), amount);
// repaid amount increases principal available (we consider it returns to principal)
emit Repaid(msg.sender, amount);
}
}
