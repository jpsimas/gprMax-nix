import h5py
import numpy as np
import matplotlib.pyplot as plt
from gprMax.post_processing import calculate_fft

# Load data
filename = "patch_antenna"
f = h5py.File(filename + ".out", "r")
rx1_name = list(f["/rxs"].keys())[0] # Point on ground
rx2_name = list(f["/rxs"].keys())[1] # Point on patch

# Get time domain data
t = f["/rxs/" + rx1_name + "/" + "Time"][:]
V1 = f["/rxs/" + rx1_name + "/" + "Vz"][:] # Voltage at rx1
V2 = f["/rxs/" + rx2_name + "/" + "Vz"][:] # Voltage at rx2
I = f["/rxs/" + rx1_name + "/" + "Iz"][:] # Current is the same for both points in the gap

# Calculate input voltage (difference across the gap)
Vin = V2 - V1

# Calculate input impedance Zin = V/I
Zin = np.fft.fft(Vin) / np.fft.fft(I)
freq = np.fft.fftfreq(len(t), t[1]-t[0])

# Calculate S11 (assuming 50 Ohm reference impedance Z0)
Z0 = 50
S11 = (Zin - Z0) / (Zin + Z0)
S11_dB = 20 * np.log10(np.abs(S11))

# Plot
plt.figure()
plt.plot(freq[freq>0]/1e9, S11_dB[freq>0])
plt.xlim(0, 5) # Show up to 5 GHz
plt.ylim(-20, 0) # Relevant S11 range
plt.xlabel("Frequency (GHz)")
plt.ylabel("S$_{11}$ (dB)")
plt.grid(True)
plt.title("Return Loss (S11) of Patch Antenna")
plt.show()

