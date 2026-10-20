# Reconfigurable Cryptographic Co-Processor for RISC-V-Based IoT Systems

A hardware-accelerated cryptographic architecture integrating AES-128 and PRESENT with a RISC-V processor, targeting resource-efficient encryption for resource-constrained IoT systems.

## Overview

This project implements and evaluates a reconfigurable cryptographic co-processor supporting AES-128 and PRESENT encryption. The design explores hardware sharing between the two cryptographic algorithms to reduce resource utilization while retaining support for both encryption modes.

The project includes standalone algorithm implementations, an unshared architecture, and a shared architecture integrated with a RISC-V processor.

## Architecture

The project evaluates the following configurations:

- **Standalone AES-128:** Independent AES encryption implementation.
- **Standalone PRESENT:** Independent PRESENT encryption implementation.
- **Unshared Architecture:** AES and PRESENT implemented without sharing their hardware resources.
- **Shared Architecture:** A resource-shared implementation supporting both algorithms.
- **RISC-V Integration:** Integration of the cryptographic architecture with a RISC-V processor for processor-controlled encryption.

## Key Features

- Support for AES-128 and PRESENT encryption.
- Shared and unshared hardware architectures.
- RISC-V processor integration.
- RTL simulation and functional verification.
- Comparative evaluation of logic utilization, power, timing, latency, and throughput.

## Technology Stack

- Verilog HDL
- RISC-V / PicoRV32
- AES-128 and PRESENT
- RTL simulation and verification
- FPGA/ASIC design metrics analysis

## Results

The shared architecture was evaluated against the unshared implementation to study hardware resource and power trade-offs.

- **Logic elements:** Reduced from 4,575 to 1,531 (66.54% reduction).
- **Total power:** Reduced from 280.77 mW to 267.83 mW (4.61% reduction).

The shared architecture supports both encryption algorithms with reduced logic utilization, while the implementation results also demonstrate trade-offs in timing and performance.

## Project Status

RTL design, architecture integration, functional verification, and implementation-metric evaluation have been completed for the project scope. FPGA implementation is outside the scope of this project.

## Repository Contents

The repository contains the available RTL source files, testbenches, and supporting documentation for the cryptographic algorithms and their integration. Refer to the project folders for implementation-specific details.
