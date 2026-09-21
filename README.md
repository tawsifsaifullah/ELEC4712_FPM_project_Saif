# ELEC4712_FPM_project_Saif

My workspace for fourier ptychographic microscopy system development and implementation.

## Recommended research papers for this project

The following papers are the most relevant references for improving this work and turning a Raspberry Pi microscope into a working Fourier Ptychographic Microscope (FPM).

### 1. Foundational FPM paper

- **Zheng, G., Horstmeyer, R., Yang, C. (2013)**  
  *Wide-field, high-resolution Fourier ptychographic microscopy*  
  Why it matters: this is the core FPM paper and explains the imaging concept, synthetic aperture idea, and reconstruction workflow that the whole system is based on.

### 2. Best practical reference for this repository

- **Aidukas, T., Eckert, R., Harvey, A. R., Waller, L., Konda, P. C. (2019)**  
  *Low-cost, sub-micron resolution, wide-field computational microscopy using open-source hardware*  
  Why it matters: this is the most directly useful paper for a low-cost Raspberry Pi FPM build. It covers hardware design, Raspberry Pi imaging, Bayer sensor handling, aberration correction, and misalignment compensation.  
  Open access: https://pmc.ncbi.nlm.nih.gov/articles/PMC6520337/

### 3. Raspberry Pi specific FPM implementation

- **Konda, Pavan Chandra, Aidukas, Tomas, Taylor, Jonathan and Harvey, Andrew R. (2017)**  
  *Miniature Fourier ptychography Microscope using Raspberry Pi Camera and Hardware.* Imaging and Applied Optics 2017, San Francisco, CA, USA, 26-29 Jun 2017. DOI: 10.1364/3D.2017.JTu5A.17  
  Why it matters: this conference paper is closely aligned with the hardware direction of this project and is useful for practical implementation details using Raspberry Pi components.  
  Repository record: http://eprints.gla.ac.uk/145088/

### 4. Validation and performance testing

- **Yang, H. J., et al. (2024)**  
  *Optical resolution and MTF of a low-cost Fourier ptychography microscope using a Raspberry Pi computer*  
  Why it matters: this is useful after assembly to evaluate image quality, optical resolution, and whether the final system is performing as expected.

## Suggested reading order

1. Aidukas et al. (2019)
2. Konda et al. (2017)
3. Zheng et al. (2013)
4. Yang et al. (2024)

## Key topics to extract from the papers

- LED array layout and illumination sequence
- Raspberry Pi camera and Bayer sensor handling
- Sample-to-LED distance calibration
- Fourier ptychographic reconstruction algorithm
- Aberration correction and misalignment correction
- Resolution validation using test targets
