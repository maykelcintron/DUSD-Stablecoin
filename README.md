# 🛡️ Security Audit & Architecture Documentation: `StablecoinEngine`

> **Auditor Profile Review:** This document presents an architectural and technical security review of the `StablecoinEngine` contract, a Collateralized Debt Position (CDP) engine designed for the issuance and management of the decentralized stablecoin `DUSD`.

---

## 🏗️ 1. System Architecture & Overview

The `StablecoinEngine` contract acts as the financial core (*Engine*) governing the interaction between ETH collateral deposits, the issuance of `DUSD` debt (backed by collateral), user position health factors, and the automated liquidation mechanism for under-collateralized positions.

### Key Components:
* **Collateral (`collateralDeposited`):** Native asset (ETH) deposited by users via `depositCollateral()`.
* **Debt (`dusdMinted`):** Amount of `DUSD` tokens minted by the user against their collateral.
* **Price Oracle (`MockPriceOracle`):** Simulated external provider that feeds the price of ETH in USD.
* **Reentrancy Protection:** Inherits OpenZeppelin's `ReentrancyGuard` to secure critical fund transfer functions.

---

## 📊 2. Critical Parameters & Constants

The system operates under the following hardcoded mathematical thresholds:

| Parameter | Value | Security Description |
| :--- | :---: | :--- |
| `COLLATERAL_RATIO` | **150** (150%) | Minimum collateralization ratio required to mint new `DUSD` or withdraw excess collateral. |
| `UMBRAL_LIQUIDITY` | **120** (120%) | Critical health level (*Liquidation Threshold*). If the health factor drops below this value, the position becomes eligible for liquidation. |
| `BONUS_LIQUIDITY` | **10** (10%) | Percentage incentive awarded to the liquidator in the form of extra collateral seized from the insolvent user's position. |
| `PRECISION` | **100** | Base scaling factor used to maintain precision in health factor calculations. |

---

## 🔒 3. Security Analysis & Invariants

As part of the audit review, the following structural security properties were validated:

1. **Checks-Effects-Interactions (CEI) Pattern:** 
   In functions like `redeemCollateral` and `liquidity`, internal state changes (reduction of debt and collateral balances) are executed *before* performing the external ETH transfer call (`msg.value.call{value:...}("")`), preventing classic reentrancy vectors (additionally reinforced with the `nonReentrant` modifier).
2. **Structural Insolvency Protection:**
   The `mintDUSD` function strictly validates that, after minting, the user's health factor remains greater than or equal to `COLLATERAL_RATIO` (150%).
3. **Incentivized Liquidation Mechanism (`liquidity`):**
   Allows solvent third parties to clear bad debt from insolvent users (whose health factor is < 120%) by burning `DUSD` in exchange for receiving equivalent collateral plus a 10% bonus.

---

## 🛠️ 4. Public Interface Specification

* `depositCollateral() external payable`: Allows depositing ETH as collateral into the vault.
* `mintDUSD(uint256 amount) external`: Mints new `DUSD` tokens, validating the resulting collateralization ratio.
* `burnDUSD(uint256 amount) external`: Burns `DUSD` tokens to reduce personal debt.
* `redeemCollateral(uint256 amount) external`: Withdraws excess collateral, ensuring the remaining position stays healthy (>= 150%) or debt-free.
* `liquidity(address user, uint256 debtToCover) external`: Liquidates a position below the security threshold, transferring collateral with a bonus to the liquidator.
* `getHealthFactor(address user) external view returns (uint256)`: Numerically calculates a user's current health index.