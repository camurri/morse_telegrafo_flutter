import numpy as np
from scipy.io.wavfile import write

def generate_tone(filename, freq=600, duration_s=10, sample_rate=44100):
    t = np.linspace(0, duration_s, int(sample_rate * duration_s), False)
    tone = 0.5 * np.sin(2 * np.pi * freq * t)
    audio = np.int16(tone * 32767)
    write(filename, sample_rate, audio)
    print(f'{filename} gerado com {duration_s}s de duração a {freq}Hz.')

if __name__ == "__main__":
    generate_tone('tone_500.wav', freq=500)
    generate_tone('tone_700.wav', freq=700)
    generate_tone('tone_900.wav', freq=900)
