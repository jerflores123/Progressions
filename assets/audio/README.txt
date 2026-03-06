This directory is reserved for guitar audio samples.

The app generates synthesized chord tones automatically at runtime, so no
audio files need to be placed here for the app to work.

If you want to replace the synthesized audio with real guitar samples,
add WAV files named like:

  guitar_C.wav
  guitar_Dm.wav
  guitar_Em.wav
  guitar_F.wav
  guitar_G.wav
  guitar_Am.wav
  guitar_Bdim.wav
  ...etc.

Then update AudioService to load from assets instead of generating WAVs.
