# Using Silicon Labs EFR32 LDMA

# References
[Silabs Application Note](https://www.silabs.com/documents/public/application-notes/AN1029-efm32-ldma.pdf): provides an accurate description of the LDMA. The current text is mostly another way to say the same thing.

# Basic Idea
A DMA (Direct Memory Access) provides a way to move data to/from memory or peripherals without using the CPU.
Silabs' LDMA (Linked DMA) gives us a possibility to set up a chain of different DMA configurations that, once started, will be entirely handled by the DMA controller.

Because Silabs provide a comprehensive set of instructions to program the DMA controller, the challenge becomes to build a sequence that will require the CPU as little as possible, and avoid interruptions as much as possibles.

# Data structures
LDMA_Descriptor_t:
- structReq: if set, start transfer as soon as descriptor is loaded, else wait for signal

LDMA_DESCRIPTOR_SINGLE_M2P_BYTE:
- This macro creates a descriptor that does not link to anything, ie: LDMA will stop after this transfer.

LDMA_DESCRIPTOR_LINKREL_M2P_BYTE:
- This macro creates a descriptor that can link to another descriptor. The "linkjmp" is the relative index of the next descriptor in the desciptor table. The documentation gives -1, 0 and 1 as examples but any value (ie: -3) is possible.


# Example Use Case: motor control
Imagine implementing a DC motor controller where speed depends on the duty cycle of a PWM.
If we want to handle smooth acceleration (S-curve motion), we need to continuously adjust the PWM duty cycle to reflect the acceleration/deceleration.
While a very versatile way to do this uses a timer, it is also an interesting use case of the LDMA if we can build a linked list that implements the "program" of accelerating, moving at constant speed for a defined duration, and decelerating.

## Involved peripherals
- LDMA
- Timer for PWM generation

CPU involvement will be reduced to the minimal, at the expense of storage space.

## Required Steps
We will create LDMA descriptors to handle the following steps:
1. Acceleration: memory-to-peripheral copy from a hard-coded buffer (that contains the acceleration curve) to the Timer module's CCVB register that controls the PWM duty cycle
1. Travel: constant speed for the duration of the movement. We need not (and cannot efficiently) use LDMA for this, we'll have to use the CPU and a Timer.
1. Deceleration: acceleration symetrical operation. We will try to reuse the same memory buffer as for acceleration.

### Acceleration
