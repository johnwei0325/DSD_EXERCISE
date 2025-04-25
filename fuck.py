# Define the matrix A and the b values for the Gauss-Seidel iteration

import numpy as np

# Matrix size
N = 16

# Construct matrix A based on the given pattern (pentadiagonal-like)
A = np.zeros((N, N), dtype=int)
for i in range(N):
    for offset, val in zip([-3, -2, -1, 0, 1, 2, 3], [-1, 6, -13, 20, -13, 6, -1]):
        j = i + offset
        if 0 <= j < N:
            A[i][j] = val

# Given b values in hex (assumed 2's complement 16-bit signed integers)
b_hex = [
    "00F8", "FD56", "6086", "DA68", "F30F", "76A9", "8AD4", "7913",
    "B070", "2AC8", "1621", "2CD4", "DC6C", "1ECA", "4FA7", "84EF"
]

# Convert b to signed integers
def hex_to_signed_int(h):
    val = int(h, 16)
    if val >= 0x8000:
        val -= 0x10000
    return val

b = np.array([hex_to_signed_int(x) for x in b_hex], dtype=int)

# Initialize x^(0) as b / diag(A)
x0 = b.astype(float) / A.diagonal()

# Perform one Gauss-Seidel iteration
#x1 = np.copy(x0)
#for i in range(N):
#    sigma = 0.0
#    for j in range(N):
#        if j != i:
#            sigma += A[i][j] * x1[j] if j < i else A[i][j] * x0[j]
#    x1[i] = (b[i] - sigma) / A[i][i]

x_gs = np.copy(x0)
print(x_gs)
for k in range(1):
    for i in range(N):
        sigma = 0.0
        for j in range(N):
            if j != i:
                sigma += A[i][j] * x_gs[j]
                if i==0:
                    print(j, A[i][j], x_gs[j]*65536, sigma*65536)
        x_gs[i] = (b[i] - sigma) / A[i][i]
print(x_gs)
