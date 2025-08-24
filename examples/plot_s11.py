import numpy as np
import matplotlib.pyplot as plt
from scipy.fft import fft, fftfreq
import h5py

def plot_s11_and_impedance(filename, rx1_index=0, rx2_index=1, dt=3e-9, z0=50):
    """
    Correct S11 and impedance calculation using magnetic fields for current
    """
    
    with h5py.File(filename, 'r') as f:
        # Get electric field from both receivers (for voltage)
        rx1_ez = f[f'/rxs/rx{rx1_index+1}/Ez'][:]
        rx2_ez = f[f'/rxs/rx{rx2_index+1}/Ez'][:]
        
        # Get magnetic field near the feed point for current calculation
        # Use the same receiver or a nearby one that has H-field components
        # For a z-oriented feed, we need H_phi or (Hx, Hy) around the pin
        hx = f[f'/rxs/rx{rx1_index+1}/Hx'][:]
        hy = f[f'/rxs/rx{rx1_index+1}/Hy'][:]
        
        time = np.linspace(0, dt, len(rx1_ez))
    
    # Calculate voltage across substrate
    substrate_thickness = 0.0016  # Your substrate thickness in meters
    V_in = (rx2_ez - rx1_ez) * substrate_thickness
    
    # Calculate current using Ampere's law: ∮H·dl = I
    # For a pin feed, the current can be estimated from the circulating magnetic field
    # I ≈ H_phi * 2πr, where r is the distance from the feed pin
    
    # Estimate current from magnetic field components
    # For a z-oriented current, the magnetic field circulates around it
    # |H| = sqrt(Hx² + Hy²) gives the magnitude of the circulating field
    H_magnitude = np.sqrt(hx**2 + hy**2)
    
    # Current is related to the circulating magnetic field
    # I = ∮H·dl ≈ 2πr * H_phi, where r is the effective radius
    # For typical patch feeds, r is on the order of the substrate thickness
    effective_radius = substrate_thickness / 2  # Reasonable estimate
    I_in = 2 * np.pi * effective_radius * H_magnitude
    
    # Frequency domain analysis
    n = len(V_in)
    freq = fftfreq(n, d=time[1]-time[0])[:n//2]
    
    # Apply windowing
    V_in_fft = fft(V_in)[:n//2]
    I_in_fft = fft(I_in)[:n//2]
    
    # Calculate input impedance properly: Z_in = V_in / I_in
    # Avoid division by zero
    I_in_fft = np.where(np.abs(I_in_fft) < 1e-12, 1e-12, I_in_fft)
    Z_in = V_in_fft / I_in_fft
    
    # Calculate reflection coefficient
    S11 = (Z_in - z0) / (Z_in + z0)
    S11_db = 20 * np.log10(np.abs(S11))
    
    # Plot results
    fig, (ax1, ax2, ax3, ax4) = plt.subplots(4, 1, figsize=(12, 16))
    
    # Plot S11
    ax1.plot(freq/1e9, S11_db, 'b-', linewidth=2)
    ax1.set_xlim(1, 4)
    ax1.set_ylim(-40, 5)
    ax1.set_xlabel('Frequency (GHz)')
    ax1.set_ylabel('S₁₁ (dB)')
    ax1.set_title('Return Loss (S₁₁)')
    ax1.grid(True)
    ax1.axhline(y=-10, color='r', linestyle='--', alpha=0.8)
    
    # Plot impedance (real and imaginary)
    ax2.plot(freq/1e9, np.real(Z_in), 'b-', label='Real(Z_in)', linewidth=2)
    ax2.plot(freq/1e9, np.imag(Z_in), 'r-', label='Imag(Z_in)', linewidth=2)
    ax2.set_xlim(1, 4)
    ax2.set_xlabel('Frequency (GHz)')
    ax2.set_ylabel('Impedance (Ω)')
    ax2.set_title('Input Impedance')
    ax2.grid(True)
    ax2.axhline(y=50, color='g', linestyle='--', alpha=0.8, label='50 Ω')
    ax2.axhline(y=0, color='k', linestyle='-', alpha=0.3)
    ax2.legend()
    
    # Plot voltage and current in time domain
    ax3.plot(time*1e9, V_in, 'b-', label='Voltage (V)', linewidth=2)
    ax3.set_xlabel('Time (ns)')
    ax3.set_ylabel('Voltage (V)')
    ax3.set_title('Time Domain Voltage')
    ax3.grid(True)
    ax3.legend()
    
    ax4.plot(time*1e9, I_in, 'r-', label='Current (A)', linewidth=2)
    ax4.set_xlabel('Time (ns)')
    ax4.set_ylabel('Current (A)')
    ax4.set_title('Time Domain Current')
    ax4.grid(True)
    ax4.legend()
    
    plt.tight_layout()
    plt.show()
    
    # Print results around 2.4 GHz
    mask = (freq > 2e9) & (freq < 3e9)
    if np.any(mask):
        min_idx = np.argmin(S11_db[mask])
        resonant_freq = freq[mask][min_idx] / 1e9
        min_s11 = S11_db[mask][min_idx]
        z_at_resonance = Z_in[mask][min_idx]
        
        print(f"\n=== ANTENNA RESULTS ===")
        print(f"Resonant frequency: {resonant_freq:.3f} GHz")
        print(f"Minimum S₁₁: {min_s11:.2f} dB")
        print(f"Input impedance: {np.real(z_at_resonance):.1f} + j{np.imag(z_at_resonance):.1f} Ω")
        
        # Calculate VSWR
        s11_mag = np.abs(S11[mask][min_idx])
        vswr = (1 + s11_mag) / (1 - s11_mag) if s11_mag < 1 else float('inf')
        print(f"VSWR: {vswr:.2f}")

# Run the analysis
if __name__ == "__main__":
    filename = "patch.out"
    plot_s11_and_impedance(filename, dt=3e-9, z0=50)
    
