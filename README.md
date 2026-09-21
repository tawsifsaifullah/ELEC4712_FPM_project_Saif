# ELEC4712_FPM_project_Saif
My workspace for fourier ptychographic microscopy system development and implementation.

## MATLAB starter workflow

This repository now includes a minimal MATLAB workflow for:

- simulating a Fourier ptychographic microscopy dataset
- reconstructing a higher resolution complex object from the simulated captures
- generating a Raspberry Pi microscope capture manifest that can be consumed by a programmable acquisition service

All MATLAB files are in the repository `matlab/` directory.

## Files

- `run_fpm_simulation_demo.m` — end-to-end simulation and reconstruction demo
- `run_raspberry_pi_capture_plan_demo.m` — creates a CSV/MAT capture plan for a Raspberry Pi driven microscope
- `fpm_default_config.m` — editable optical, sensor, LED, and Raspberry Pi settings
- `fpm_generate_sample_object.m` — synthetic complex sample for simulation
- `fpm_generate_led_positions.m` — LED geometry, ordering, and Fourier shift calculation
- `fpm_simulate_dataset.m` — low-resolution image simulation for each LED illumination
- `fpm_reconstruct.m` — iterative Fourier ptychographic reconstruction
- `fpm_plan_raspberry_pi_sequence.m` — acquisition manifest builder

## How to run

From MATLAB, run the scripts using repository-relative paths:

```matlab
run('matlab/run_fpm_simulation_demo.m')
run('matlab/run_raspberry_pi_capture_plan_demo.m')
```

## Notes for thesis implementation

- Start by tuning `fpm_default_config.m` so the LED pitch, LED height, NA, magnification, sensor size, and exposure settings match your microscope.
- The simulation path is self-contained and is useful for validating reconstruction behavior before hardware work.
- The Raspberry Pi manifest contains LED order, exposure time, settling time, and a configurable capture endpoint so the same MATLAB planning step can drive a microscope acquisition service running on the Raspberry Pi.
