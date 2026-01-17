# --- 1. Load Libraries ---
install.packages("Rglpk")
library(Rglpk)
# --- 2. Load Data Files ---
# Load Benefit Payments
benefit_data <- read.table("../data/BenefitPayments.txt", header = FALSE)
n_quarters <- benefit_data[1, 1] # Should be 80
# Vector of benefit payments (B_t) for t=1 to 80
B <- benefit_data[-1, 1]
# Load Bond Data
bond_data_raw <- read.table("../data/BondData.txt", header = FALSE, skip = 1)
n_bonds <- nrow(bond_data_raw) # Should be 230
colnames(bond_data_raw) <- c("Type", "Rating", "Price", "UpperBound")
# Extract bond data into vectors
P <- bond_data_raw$Price # Price (P_i)
S <- bond_data_raw$Rating # Credit Score (S_i)
U <- bond_data_raw$UpperBound # Upper $ Bound (U_i)
Type <- bond_data_raw$Type # Type (1=CIPS, 2=TIPS, 3=Nominal Bonds, 4=SMA)
# Load Cash Flow Matrices (Rows = Quarters, Cols = Bonds)
# Nominal Cash Flows (N_it)
N <- as.matrix(read.table("../data/NomCashflow.txt", header = FALSE))
# Real (Inflation-Linked) Cash Flows (R_it)
R <- as.matrix(read.table("../data/RealCashflow.txt", header = FALSE))
# --- 3. Assign Parameters ---
saving_rate <- 0.0201
inflation_rate <- 0.03
credit_limit <- 0.40
allocation_limit_CIPS <- 0.30
allocation_limit_TIPS <- 0.80
allocation_limit_Nominal_Bond <- 0.80
allocation_limit_SMAs <- 0.10
nominal_cash_Limit <- 0.20
# --- 4. Define Decision Variables ---
n_vars <- n_bonds + n_quarters + 1 # 230 (x_i) + 81 (c_t, t=0 to 80)
# Vars 1 to 230 are bond units x_i
# Vars 231 to 311 are cash c_0, c_1, ..., c_80
# --- 5. Define Objective Function ---
# Minimize Z = sum(x_i * P_i) + c_0 + c_80
obj <- numeric(n_vars)
# Bond purchase cost
obj[1:n_bonds] <- P
# Initial cash deposit c_0
obj[n_bonds + 1] <- 1
# Final cash holding c_80
obj[n_vars] <- 1
# --- 6. Define Constraints (mat, dir, rhs) ---
# Initialize constraint matrix, direction, and RHS vectors
mat_list <- list()
dir_vec <- c()
rhs_vec <- c()
# --- Constraint 1: Benefit Payment Coverage (80 constraints) ---
# (c_{t-1} * eˆ((saving_rate-inflation_rate/4)) + sum(x_i * (R_it + N_it / eˆ(-inflation_limit*t/4)) - c
for (t in 1:n_quarters) {
row <- numeric(n_vars)
# sum(x_i * (R_it + N_it * eˆ(-inflation_limit*t/4)))
inflation_discount <- exp(inflation_rate*t/4)
row[1:n_bonds] <- R[t, ] + (N[t, ] / inflation_discount)
# + c_{t-1} * eˆ((saving_rate-inflation_rate/4))
# Note: c_0 is var 231, c_1 is 231, ..., c_{t-1} is 231 + (t-1)
row[n_bonds + t] <- exp((saving_rate-inflation_rate)/4)
# - c_t
row[n_bonds + t + 1] <- -1
mat_list[[length(mat_list) + 1]] <- row
dir_vec <- c(dir_vec, ">=")
rhs_vec <- c(rhs_vec, B[t])
}
# --- Constraint 2: Credit Quality (1 constraint) ---
# sum(x_i * (P_i * S_i - credit_limit * P_i)) <= 0
row <- numeric(n_vars)
row[1:n_bonds] <- P * S - credit_limit * P
mat_list[[length(mat_list) + 1]] <- row
dir_vec <- c(dir_vec, "<=")
rhs_vec <- c(rhs_vec, 0)
# --- Constraint 3: Maximum Allocation by Bond Type (4 constraints) ---
# CIPS (Type 1) <= 30%
row_cips <- numeric(n_vars)
row_cips[1:n_bonds] <- ifelse(Type == 1, P * (1 - allocation_limit_CIPS), P * (-allocation_limit_CIPS))
mat_list[[length(mat_list) + 1]] <- row_cips
dir_vec <- c(dir_vec, "<=")
rhs_vec <- c(rhs_vec, 0)
# TIPS (Type 2) <= 80%
row_tips <- numeric(n_vars)
row_tips[1:n_bonds] <- ifelse(Type == 2, P * (1 - allocation_limit_TIPS), P * (-allocation_limit_TIPS))
mat_list[[length(mat_list) + 1]] <- row_tips
dir_vec <- c(dir_vec, "<=")
rhs_vec <- c(rhs_vec, 0)
# Nominal (Type 3) <= 80%
row_nom <- numeric(n_vars)
row_nom[1:n_bonds] <- ifelse(Type == 3, P * (1 - allocation_limit_Nominal_Bond), P * (-allocation_limit_
mat_list[[length(mat_list) + 1]] <- row_nom
dir_vec <- c(dir_vec, "<=")
rhs_vec <- c(rhs_vec, 0)
# SMAs (Type 4) <= 10%
row_smas <- numeric(n_vars)
row_smas[1:n_bonds] <- ifelse(Type == 4, P * (1 - allocation_limit_SMAs), P * (-allocation_limit_SMAs))
mat_list[[length(mat_list) + 1]] <- row_smas
dir_vec <- c(dir_vec, "<=")
rhs_vec <- c(rhs_vec, 0)
# --- Constraint 4: Nominal Cash Flow Limit (1 constraint) ---
# sum(x_i * [0.8 * sum_t(N_it) - 0.2 * sum_t(R_it)]) <= 0
Total_N <- colSums(N) # Total nominal CF per bond
Total_R <- colSums(R) # Total real CF per bond
row <- numeric(n_vars)
row[1:n_bonds] <- (1-nominal_cash_Limit) * Total_N - (nominal_cash_Limit * Total_R)
mat_list[[length(mat_list) + 1]] <- row
dir_vec <- c(dir_vec, "<=")
rhs_vec <- c(rhs_vec, 0)
# --- Combine constraints into a single matrix ---
mat_constraints <- do.call(rbind, mat_list)
# --- 6. Define Bounds ---
# Constraint 5: Individual Bond Availability (x_i * P_i <= U_i) => x_i <= U_i / P_i
# Constraint 6: Non-Negativity (x_i >= 0, c_t >= 0)
# Rglpk handles division by zero gracefully (Inf), but we'll be careful
upper_x <- U / P
# Handle any P_i = 0 cases, though unlikely for price
upper_x[is.infinite(upper_x)] <- 1e20 # A very large number
upper_x[is.na(upper_x)] <- 0 # If 0/0, can't buy
bounds <- list(
# Lower bounds: x_i >= 0, c_t >= 0
lower = list(ind = 1:n_vars, val = rep(0, n_vars)),
# Upper bounds: x_i <= U_i / P_i. Cash (c_t) is unbounded above.
  upper = list(ind = 1:n_bonds, val = upper_x)
)
# --- 7. Solve the LP ---
solution <- Rglpk_solve_LP(
obj = obj,
mat = mat_constraints,
dir = dir_vec,
rhs = rhs_vec,
bounds = bounds,
max = FALSE # We are minimizing
)
# --- 8. Display Solution ---
if (solution$status == 0) {
# Extract solution variables
vars <- solution$solution
x <- vars[1:n_bonds]
c_cash <- vars[(n_bonds + 1):n_vars] # c_0, c_1, ..., c_80
total_cost_Z <- solution$optimum
initial_bond_cost <- sum(x * P)
initial_cash_c0 <- c_cash[1] # c_0
final_cash_c80 <- c_cash[n_quarters + 1] # c_80
purchases <- data.frame(
Bond_ID = 1:n_bonds,
Type = Type,
Units_Purchased = x,
Dollar_Value = x * P,
Percent_of_Bond_Portfolio = (x * P) / initial_bond_cost
)
# Filter for non-trivial purchases
purchases_filtered <- purchases[purchases$Dollar_Value > 1, ]
purchases_filtered <- purchases_filtered[order(-purchases_filtered$Dollar_Value), ]
if (nrow(purchases_filtered) > 0) {
print(head(purchases_filtered, 20), row.names = FALSE)
} else {
cat("No significant bond purchases recommended.\n")
}
# Credit Quality
avg_credit <- sum(x * P * S) / initial_bond_cost
# Allocation by Type
alloc_cips <- sum(purchases$Dollar_Value[purchases$Type == 1]) / initial_bond_cost
alloc_tips <- sum(purchases$Dollar_Value[purchases$Type == 2]) / initial_bond_cost
alloc_nom <- sum(purchases$Dollar_Value[purchases$Type == 3]) / initial_bond_cost
alloc_smas <- sum(purchases$Dollar_Value[purchases$Type == 4]) / initial_bond_cost
  # Nominal CF Limit
total_nom_cf <- sum(Total_N * x)
total_real_cf <- sum(Total_R * x)
nom_cf_ratio <- total_nom_cf / (total_nom_cf + total_real_cf)
constraint_labels <- c(
paste("Benefit_Q", 1:n_quarters, sep = ""), # Constraints 1-80
"Credit_Quality_Limit", # Constraint 81
"Alloc_CIPS_Limit", # Constraint 82
"Alloc_TIPS_Limit", # Constraint 83
"Alloc_Nominal_Limit", # Constraint 84
"Alloc_SMAs_Limit", # Constraint 85
"Nominal_CF_Limit" # Constraint 86
)
duals_df <- data.frame(
Constraint_ID = 1:length(constraint_labels),
Constraint_Name = constraint_labels,
Shadow_Price = solution$auxiliary$dual
)
} else {
cat(sprintf("Optimal solution NOT found. Solver status: %d\n", solution$status))
}
# --- 9. Print Analysis ---
cat(sprintf("Dollar-Weighted Avg. Credit Score: %.4f (Limit: %.1f)\n", avg_credit, credit_limit))
cat(sprintf("Allocation CIPS: %.2f%% (Limit: 30%%)\n", alloc_cips * 100))
cat(sprintf("Allocation TIPS: %.2f%% (Limit: 80%%)\n", alloc_tips * 100))                                                                                    
cat(sprintf("Allocation Nominal: %.2f%% (Limit: 80%%)\n", alloc_nom * 100))                                                                                      
cat(sprintf("Allocation SMAs: %.2f%% (Limit: 10%%)\n", alloc_smas * 100))
cat(sprintf("Nominal CF Ratio: %.2f%% (Limit: 20%%)\n", nom_cf_ratio * 100))
duals_df                                                                                      
