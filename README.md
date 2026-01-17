# Pension Asset-Liability Management and Liability-Driven Investment Optimization
![R](https://img.shields.io/badge/r-%23276DC3.svg?style=for-the-badge&logo=r&logoColor=white)
![RStudio](https://img.shields.io/badge/RStudio-%2375AADB.svg?style=for-the-badge&logo=rstudio&logoColor=white)
![Quantmod](https://img.shields.io/badge/Quantmod-%23276DC3.svg?style=for-the-badge&logo=r&logoColor=white)
![MASS](https://img.shields.io/badge/MASS-%23276DC3.svg?style=for-the-badge&logo=r&logoColor=white)
![Rglpk](https://img.shields.io/badge/Rglpk-%23276DC3.svg?style=for-the-badge&logo=r&logoColor=white)

## Project Overview
This project develops an immunization strategy for a "closed and frozen" defined benefit (DB) pension plan. The objective is to construct an optimal fixed-income portfolio from 310 tradable securities to cover 80 quarters (20 years) of inflation-indexed benefit payments while minimizing the total economic cost to the plan sponsor.

## The Challenge: Actuarial Complexity
Managing a pension fund requires balancing precise cash flow matching with rigorous risk and regulatory constraints:
* **Liability Matching:** Covering 80 quarters of expected benefit payments indexed to CPI inflation.
* **Diverse Security Universe:** Selecting from Nominal Treasuries, TIPS, Corporate Inflation-Protected Securities (CIPS), and Secondary Market Annuities (SMAs). Each bond class has certain features in cash flows and payment.
* **Inflation Risk:** Deflating nominal cash flows to match real liability values (used projected 3.0% per year for simplicity).
* **Credit Risk Management:** Assigning each bond a certain credit score and make sure the total dollar-weighted portfolio credit score under some threshold (used 0.4). Also, the ratings for bond has been adjusted, and the Default & Downgrade risk needs to be considered, risk reserve (cash) is needed when the portfolio grows

## Methodology & Optimization Logic
### 1. Objective Function
The model utilizes **Linear Programming** to minimize the total cost ($Z$), defined as:
$$Min \ Z = \sum (x_i \cdot P_i) + c_0 + c_{80}$$
Where:
* $x_i \cdot P_i$: Total cost of bond purchases.
* $c_0$: Initial cash deposit.
* $c_{80}$: Surplus funds remaining after 20 years (to minimize tax inefficiency).

### 2. Constraint Framework
* **Benefit Coverage:** Ensuring $(Cash \ Available)_t \geq (Benefit \ Payment)_t$ for all $t \in [1, 80]$.
* **Allocation Caps:** Diversification limits prevent over-exposure: TIPS (80%), Nominal Bonds (80%), CIPS (30%), and SMAs (10%)].
* **Structural Cash Flow Limit:** Nominal cash flows (non-indexed) are capped at 20% of total portfolio cash flows to control long-term inflation exposure.

### 3. Actuarial Techniques
* **Sensitivity Analysis (Shadow Pricing):** Evaluated the economic impact of relaxing credit quality and allocation constraints to identify cost-saving opportunities.
* **Cash Reinvestment:** Modeled excess funds (cash) earning a risk-free nominal interest rate between quarterly payment cycles (use 2.0% for simpliciy). Note that, the rate should be adjusted with the inflation rate

## Tech Stack
* **Language:** R
* **Solver:** `Rglpk` (GNU Linear Programming Kit) 
* **Reporting:** R Markdown & LaTeX

## How to Run
1. Ensure `BenefitPayments.txt`, `BondData.txt`, `NomCashflow.txt`, and `RealCashflow.txt` are in the `/data` directory.
2. Run `src/bond_optimizer.R` to execute the solver and generate the optimal purchase list.
