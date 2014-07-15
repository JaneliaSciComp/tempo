============================
Getting Your Data into Tempo
============================

Tempo knows how to open many formats of video, audio and annotation and can be easily :doc:`extended </Customizing/index>` to handle new formats.

-----
Video
-----

Tempo can open any video format supported by MATLAB's VideoReader function.  See the MATLAB documentation for the exact formats but AVI, MPEG and QuickTime movies are available on most platforms.  All video files are displayed in a :doc:`video panel </UserInterface/VideoPanel>` on the left side of the Tempo window.  Custom video formats can be supported by :doc:`adding a new recording type </Customizing/Recordings>`.

-----
Audio
-----

Tempo can open any audio format supported by MATLAB's audioread function.  See the MATLAB documentation for the exact formats but WAV and MP3 are available on most platforms.  Audio files are displayed with :doc:`waveform </UserInterface/WaveformPanel>` and/or :doc:`spectrogram </UserInterface/SpectrogramPanel>` panels in the timeline on the right side of the Tempo window.  Custom audio formats can also be supported by :doc:`adding a new recording type </Customizing/Recordings>`.

-----------
Annotations
-----------

Tempo can import annotation files created by `Noldus Observer  <http://www.noldus.com/human-behavior-research/products/the-observer-xt>`_ and `VCode <http://http://social.cs.uiuc.edu/projects/vcode.html>`_.  New features can be manually annotated or discovered using automated detectors.  Custom annotation formats can be supported by :doc:`adding a new feature importer </Customizing/FeatureImporters>` and .
new :doc:`feature detectors </Customizing/FeatureDetectors>` can also be added.