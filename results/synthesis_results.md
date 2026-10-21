# Synthesis Results and Architecture Comparison

## 1. Overview

This report compares the synthesis metrics of the shared and unshared cryptographic architectures. The comparison focuses on logic resource usage, register count, estimated power consumption, and maximum operating frequency.

## 2. Shared vs. Unshared Architecture

| Metric | Unshared Architecture | Shared Architecture |
|---|---:|---:|
| Logic Elements | 4,575 | 1,531 |
| Logic Element Utilization | 4.00% | 1.34% |
| Registers | 2,553 | 317 |
| Total Estimated Power | 280.77 mW | 267.83 mW |
| Static Power | 99.29 mW | 99.02 mW |
| Dynamic Power | 181.48 mW | 168.81 mW |
| Maximum Frequency (Fmax) | 67.05 MHz | 58.88 MHz |
| Setup Slack | 5.085 ns | 3.015 ns |
| Hold Slack | 0.401 ns | 0.402 ns |

## 3. Resource Utilization Analysis

The shared architecture uses 1,531 logic elements compared with 4,575 in the unshared architecture, representing an approximately 66.54% reduction.

The register count decreases from 2,553 to 317, corresponding to an approximately 87.58% reduction.

These results indicate a substantial reduction in the reported hardware resources when using the shared architecture.

## 4. Power Analysis

The reported total estimated power decreases from 280.77 mW to 267.83 mW, an approximately 4.61% reduction.

Dynamic power decreases from 181.48 mW to 168.81 mW, while static power changes from 99.29 mW to 99.02 mW.

These figures represent the reported synthesis-tool estimates; they should not be interpreted as measured power from a physical FPGA board.

## 5. Timing Analysis

The maximum reported frequency decreases from 67.05 MHz to 58.88 MHz in the shared architecture.

The shared architecture also has lower setup slack (3.015 ns versus 5.085 ns). Hold slack is similar for both configurations.

This indicates a trade-off between resource reduction and timing performance. The results should be interpreted under the same synthesis and timing constraints, where applicable.

## 6. Conclusion

The shared architecture substantially reduces the reported logic element and register counts, with a modest reduction in estimated total power. However, it also exhibits a lower maximum frequency and lower setup slack than the unshared architecture.

The comparison highlights the trade-off between hardware resource sharing and timing performance.

## 7. Scope

These figures compare the shared and unshared cryptographic architectures. They should not be presented as synthesis results for the complete RISC-V-integrated system unless that specific configuration was measured separately.

FPGA implementation and physical-board power measurements are outside the current project scope.
