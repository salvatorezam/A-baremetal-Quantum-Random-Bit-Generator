# A baremetal Quantum Random Bit Generator

This repository contains the description of an Embedded Systems project realized for the Master’s Degree Course in Computer Engineering at the University of Palermo. The project focuses on the design and implementation of a Quantum Random Bit Generator (QRBG) controlled by a single-board controller that is interfaced in bare-metal mode through Forth, a lightweight, stack-based, intermediate-level language that provides an efficient management for both computational and communication tasks.

## Table of Contents

- [A baremetal Quantum Random Bit Generator](#a-baremetal-quantum-random-bit-generation)
  - [Table of Contents](#table-of-contents)
  - [Abstract](#abstract)
  - [Quantum Bit Generation](#quantum-bit-generation)
  - [Tools](#quantum-bit-generation)
  - [Configuration](#preview)
  - [Tests](#tests)
  - [Code Navigation](#code-navigation)

![sample_img](./imgs/embedded_bb_.png)

# Abstract

The project focuses on the design and implementation of a Quantum Random Bit Generator (QRBG) controlled by a single-board controller that is interfaced in bare-metal mode through Forth, a lightweight, stack-based intermediate-level language that provides an efficient management for both computational and communication tasks.

Random bit generation is the process of producing bits that exhibit no discernible pattern or predictability, thereby appearing random. These bits are crucial for a wide array of applications across various domains, including cryptography, simulation, gaming, and secure communication protocols. Traditional methods of random bit generation, such as pseudo-random number generators (PRNGs), rely on deterministic algorithms to produce sequences of numbers that approximate randomness. However, these sequences are ultimately predictable, which can pose security risks in certain applications.

With the recent advent of Quantum Technologies, which, among all of the other things, promise to achieve such significant computational speed-ups so as to render classical, brute-force resistant cryptography obsolete, concerns arise for the security of communications. On the flipside, those very same technologies that pose a threat to the integrity of the users’ data, can be exploited to design and build mechanisms that are resistant to those point of attack.

Out of the different hardware technologies that implement the quantum paradigm, the optical/photonic one is the alternative that, due to its robustness and ease of implementation, appears to be most suitable for dealing with the exchange of information between two or more parties. It is upon those consideration that this project achieves Random Bit Generation through the realization of a laser-based physical qubit, the information unit of quantum computation, along with the (classical) embedded system that is required to control it.

Tests on the randomness of this toy system showcase the maximal entropy of the integrated half-interferometer system, proving the validity

# Quantum Bit Generation

On the breadboard, an half-interferometer configuration is built, where a Laser Diode is activated
to shine a ray of photons towards a Beam Splitter prism, which routes the beam towards two Light-
Dependent Resistors. When exiting the LD, the quantum nature of the photons is such that they
are all in superposition of states, the states being the two main polarization directions (horizontalvertical)
of the light wave.
Then, the voltages on each of those resistors is read, causing the wavefunction of the polarization
states to collapse into one of the two directions, and a bit is generated according to which
LDR receives more photons, corresponding to the preferential polarization direction chosen by the
photons at measurement. This setup, similar to that used in __[this project](https://github.com/Spooky-Manufacturing/QRNG)__ by __[Spooky Manufacturing](https://github.com/Spooky-Manufacturing/QRNG)__, is displayed in the Figure below.

![sample_img](./imgs/photoschema.png)

# Tools

The Hardware tools used to implement the baremetal QRBG are listed below:

 * Raspberry Pi 4B as main controller
 * CP2102 USB-to-TTL module for UART communication
 * 650nm, 5mW Laser Diode as photon sorce
 * 50/50 Beam Splitter prism to deviate the laser beam
 * 2 Light-Dependent Resistors for readout
 * Adafruit ADS1115 ADC module to digitalize the LDR analog inputs

# Configuration

# Synchronization

# Tests

# Code Navigation