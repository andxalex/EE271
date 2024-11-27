import math

# Configuration
INPUT_BITS = 17         # Total bits in input fixed-point number
INPUT_FRAC_BITS = 10    # Number of fractional bits in input
OUTPUT_BITS = 22        # Total bits in output fixed-point number
OUTPUT_FRAC_BITS = 17   # Number of fractional bits in output
FILENAME = "log2_rom.mem"

# Number of entries in the ROM
RANGE = 2 ** INPUT_BITS  # 131,072 entries

# Generate the ROM contents
with open(FILENAME, "w") as f:
    for i in range(RANGE):
        # Handle the special case where value is 0
        if i == 0:
            fixed_point_log2 = 0  # Logarithm undefined for 0, set to 0
        else:
            # Convert index to fixed-point input value
            value = i / (1 << INPUT_FRAC_BITS)
            # Compute logarithm
            log2_value = math.log2(value)
            # Scale to fixed-point representation with OUTPUT_FRAC_BITS fractional bits
            fixed_point_log2 = int(round(log2_value * (1 << OUTPUT_FRAC_BITS)))

            # Handle negative fixed-point numbers using two's complement
            if fixed_point_log2 < 0:
                fixed_point_log2 = (1 << OUTPUT_BITS) + fixed_point_log2  # Convert to two's complement

        # Write the fixed-point log2 value as a OUTPUT_BITS-bit binary string
        f.write(f"{fixed_point_log2:0{OUTPUT_BITS}b}\n")
print(f"Logarithm ROM data file written to {FILENAME}")
