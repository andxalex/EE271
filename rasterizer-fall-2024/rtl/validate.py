import math

# Configuration (must match the generation script)
INPUT_BITS = 17         # Total bits in input fixed-point number
INPUT_FRAC_BITS = 10    # Number of fractional bits in input
OUTPUT_BITS = 28        # Total bits in output fixed-point number
OUTPUT_FRAC_BITS = 23   # Number of fractional bits in output
FILENAME = "log2_rom2.mem"  # ROM file to validate

def validate_log2_rom():
    """
    Validates the entries of the generated ROM file.
    Prints mismatched entries, if any.
    """
    try:
        with open(FILENAME, "r") as f:
            rom_entries = f.readlines()
    except FileNotFoundError:
        print(f"Error: File '{FILENAME}' not found. Please ensure the file exists.")
        return

    errors = 0  # Count of mismatched entries
    for i, binary_str in enumerate(rom_entries):
        # Parse the binary string to get the fixed-point value
        binary_str = binary_str.strip()
        fixed_point_rom_value = int(binary_str, 2)

        # Handle two's complement for negative values
        if fixed_point_rom_value >= (1 << (OUTPUT_BITS - 1)):
            fixed_point_rom_value -= (1 << OUTPUT_BITS)

        # Convert fixed-point value to real value
        rom_log2_value = fixed_point_rom_value / (1 << OUTPUT_FRAC_BITS)

        # Recompute log2 value for validation
        if i == 0:
            recomputed_log2_value = 0  # Special case for address 0
        else:
            value = i / (1 << INPUT_FRAC_BITS)
            recomputed_log2_value = math.log2(value)

        # Scale recomputed log2 to fixed-point
        recomputed_fixed_point_value = int(round(recomputed_log2_value * (1 << OUTPUT_FRAC_BITS)))

        # Handle two's complement for recomputed values
        if recomputed_fixed_point_value < 0:
            recomputed_fixed_point_value = (1 << OUTPUT_BITS) + recomputed_fixed_point_value

        # Compare the ROM and recomputed values
        if abs(rom_log2_value - recomputed_log2_value) >= 1e-7:
            errors += 1
            print(f"Mismatch at address {i}:")
            # print(f"  ROM Binary: {binary_str}")
            # print(f"  ROM Value (Fixed-Point): {fixed_point_rom_value}")
            print(f"  ROM Value (Real):        {rom_log2_value:.6f}")
            # print(f"  Recomputed Value (Fixed-Point): {recomputed_fixed_point_value}")
            print(f"  Recomputed Value (Real): {recomputed_log2_value:.6f}")

    # Print validation summary
    if errors == 0:
        print("Validation successful: All ROM entries are correct.")
    else:
        print(f"Validation failed: {errors} mismatched entries found.")

if __name__ == "__main__":
    validate_log2_rom()
