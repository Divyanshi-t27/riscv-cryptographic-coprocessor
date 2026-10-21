# RISC-V-Based Reconfigurable Cryptographic Co-Processor

**AES-128 | PRESENT-80 | Hardware Resource Sharing | RISC-V Integration**

A digital hardware design project exploring a reconfigurable cryptographic co-processor integrated into a PicoRV32-based RISC-V system. The project focuses on AES-128 and PRESENT-80 encryption, shared versus unshared hardware architectures, and the trade-off between hardware resource utilization and timing performance.

## Overview

Cryptographic operations are increasingly important in embedded systems, where hardware resources and power consumption can be constrained. This project explores the integration of cryptographic functionality into a RISC-V-based system through a memory-mapped peripheral interface.

The co-processor supports two encryption algorithms—AES-128 and PRESENT-80—with a shared architecture designed to reuse selected hardware resources across the algorithms.

The project compares shared and unshared cryptographic architectures to evaluate the impact of resource sharing on logic utilization, register count, estimated power, and timing metrics.

## Objectives

- Explore integration of a cryptographic co-processor into a PicoRV32-based RISC-V system.
- Support AES-128 and PRESENT-80 encryption through algorithm selection.
- Develop and compare shared and unshared cryptographic hardware architectures.
- Evaluate synthesis metrics, including logic resources, registers, estimated power, and maximum operating frequency.
- Analyze the trade-off between hardware resource reduction and timing performance.

## System Architecture

The system architecture comprises the following major components:

- **PicoRV32 RISC-V Processor:** Executes the program and initiates cryptographic operations.
- **Address Decoding Logic:** Routes memory-mapped transactions to the appropriate target.
- **On-Chip RAM:** Stores program instructions and data.
- **Crypto Peripheral:** Provides the processor-facing interface for cryptographic inputs, control, status, and output.
- **Reconfigurable Cryptographic Co-Processor:** Performs the selected encryption operation.
- **Shared Controller and Datapath:** Coordinate operation sequencing and reuse selected hardware resources across AES and PRESENT.

The processor configures the cryptographic peripheral with the required inputs and algorithm selection, starts the operation, checks its status, and retrieves the resulting ciphertext.

### System-Level and Internal Architecture

![RISC-V Cryptographic System Architecture](docs/RISC-V%20Crypto%20System%20Architecture%20Diagram.png)

For a detailed explanation of the system blocks and datapath, see [`docs/design_notes.md`](docs/design_notes.md).

## Cryptographic Algorithms

### AES-128

AES is a symmetric-key block cipher that operates on 128-bit data blocks with a 128-bit key. The AES RTL includes modules for encryption operations, substitution, and key scheduling.

### PRESENT-80

PRESENT is a lightweight block cipher intended for resource-constrained hardware. The PRESENT-80 configuration uses a 64-bit data block and an 80-bit key.

Because the algorithms use different block and key widths, their interface handling and datapath operations must account for these differences.

## Shared vs. Unshared Architecture

The project includes shared and unshared cryptographic hardware implementations for architectural comparison.

- **Unshared architecture:** Provides the unshared implementation used as the comparison baseline.
- **Shared architecture:** Reuses selected hardware resources across AES and PRESENT operations, including shared control and substitution-related datapath resources.

The purpose of resource sharing is to reduce hardware utilization. Its effectiveness must also be evaluated against the resulting timing characteristics.

## Results at a Glance

The reported synthesis comparison shows that the shared architecture achieves:

- **66.54% reduction in logic elements**
- **87.58% reduction in register count**
- **4.61% reduction in total estimated power**

These reductions come with a decrease in maximum reported frequency from 67.05 MHz to 58.88 MHz, illustrating the trade-off between hardware resource sharing and timing performance.

The results refer to the reported shared-versus-unshared cryptographic architecture comparison, not necessarily the fully integrated RISC-V system. Power figures are tool estimates rather than physical-board measurements.

For the full metrics table, timing analysis, and visual comparisons, see [`results/synthesis_results.md`](results/synthesis_results.md).

## Repository Structure

```text
riscv-cryptographic-coprocessor/
├── README.md
├── docs/
│   ├── RISC-V Crypto System Architecture Diagram.png
│   ├── RISC-V Encryption Workflow Infographic.png
│   └── design_notes.md
├── firmware/
│   └── firmware_generator.py
├── results/
│   ├── resource_comparison.png
│   ├── sharing_impact.png
│   └── synthesis_results.md
└── rtl/
    ├── soc_top.v
    ├── crypto_mmio.v
    ├── AES/
    ├── PRESENT/
    ├── SHARED ARCH/
    └── ...
```

*The tree is illustrative. Refer to the repository for the complete source-file inventory and actual directory names.*

## Tools and Technologies

- Verilog HDL
- PicoRV32 RISC-V processor
- Memory-mapped peripheral interfacing
- AES-128 and PRESENT-80 cryptographic hardware
- RTL design and synthesis analysis

The exact simulation and synthesis tools, versions, target device, and constraints should be documented when confirmed from the project setup and reports.

## Project Scope and Status

The repository contains cryptographic RTL implementations, system-integration source files, architecture documentation, and a shared-versus-unshared synthesis comparison.

The current project scope does not include FPGA implementation or physical-board power measurements.

Simulation and end-to-end integration status should be described according to the tests and evidence available for the submitted source. The presence of source files or architecture diagrams alone does not establish successful end-to-end verification.

## Future Work

- Complete and document end-to-end system verification.
- Add reproducible simulation testbenches and expected-versus-observed results.
- Document the memory-mapped register map and software interface.
- Record synthesis constraints, target device details, and tool versions.
- Investigate timing optimization while retaining the resource savings of hardware sharing.

## Acknowledgements

This project was developed as part of academic work in digital hardware design and computer architecture. Third-party RTL and dependencies should be credited according to their respective licenses and redistribution requirements.

## Author

**Divyanshi Trivedi**

Electronics Engineering | VLSI Design and Technology

[GitHub Profile](https://github.com/Divyanshi-t27)
