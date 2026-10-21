# Design Notes

## 1. System Overview

The project explores a RISC-V-based cryptographic system integrating a PicoRV32 processor with a memory-mapped cryptographic peripheral. The co-processor supports AES-128 and PRESENT-80 encryption through a reconfigurable architecture.

## 2. System Architecture

The system consists of the following major components:

- **PicoRV32 Processor:** Executes the program and initiates cryptographic operations.
- **Address Decoding Logic:** Routes processor transactions to the appropriate memory-mapped peripheral.
- **On-chip RAM:** Stores program instructions and data.
- **Crypto Peripheral:** Provides registers for the plaintext, key, algorithm selection, start control, and encryption status/output.
- **Cryptographic Co-Processor:** Performs encryption using the selected algorithm.
- **Simulation/Test Interface:** Provides an interface for simulation and testing, as represented in the architecture diagram.

## 3. Reconfigurable Cryptographic Architecture

The internal architecture of `crypto_top` includes a shared controller and a shared datapath.

The controller contains algorithm-selection logic, a finite-state machine, a round counter, and control-signal generation logic. The datapath contains key and state registers, algorithm-specific operations, a shared substitution unit, and state/key update logic.

The substitution unit selects between the AES S-box and PRESENT S-box according to the selected operating mode.

## 4. Shared and Unshared Implementations

The project includes shared and unshared cryptographic architecture implementations.

The shared architecture is designed to reuse selected hardware resources across AES and PRESENT operations. The unshared architecture provides a separate implementation for comparison.

Refer to the `results/` directory for the measured synthesis comparison and the conditions under which the results were obtained.

## 5. Processor-to-Co-Processor Workflow

1. The PicoRV32 processor executes the program.
2. The processor writes the plaintext, key, and algorithm selection to the crypto peripheral.
3. A start command initiates the encryption operation.
4. The co-processor performs the selected AES or PRESENT operation.
5. The processor checks the status register for completion.
6. The processor reads the resulting ciphertext from the output registers.

## 6. Scope and Limitations

The project covers cryptographic RTL development, shared-versus-unshared architecture comparison, and RISC-V system integration work.

An FPGA implementation is not included in the current project scope. System-level functionality and integration should be described as verified only to the extent supported by available simulation results and implementation evidence.
