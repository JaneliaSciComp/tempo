========
Browsing
========

Tempo lets you browse through audio, video and annotation files, keeping everything in sync while you do it.  The main window displays any videos that you have opened on the left and any audio or annotation files on the right.  The files on the right are laid out on a common timeline that can be scrolled through, zoomed into, etc.  

----------------------
Browsing Through Video
----------------------

Tempo displays the frame at the current time for each video that you have open.  You can change the current time using the scroll bar below the :doc:`video panels </UserInterface/VideoPanel>`.

^^^^^^^^^^^^^^^^^^
Keyboard Shortcuts
^^^^^^^^^^^^^^^^^^

There are a few keyboard shortcuts to make it easier to navigate through video:

===========================  ========================
Key                          Action
===========================  ========================
:kbd:`Cmd/Ctrl-Left arrow`   Go to the first frame
:kbd:`Left arrow`            Go to the previous frame
:kbd:`Right arrow`           Go to the next frame
:kbd:`Cmd/Ctrl-Right arrow`  Go to the last frame
===========================  ========================

-----------------------------
Browsing Through the Timeline
-----------------------------

Tempo displays all audio and annotation files on a common timeline on the right side of the Tempo window.  Audio files are displayed in :doc:`waveform </UserInterface/WaveformPanel>` and/or :doc:`spectrogram </UserInterface/SpectrogramPanel>` panels while annotations are displayed in :doc:`feature </UserInterface/FeaturesPanel>` panels.  A vertical red line through the timelines indicates the current time to which all files (including video) are being synchronized.  Clicking anywhere in the timeline will set the current time.  The scrollbar below the timeline lets you browse through the entire timeline but does not change the current time.  Toolbar buttons and items in the Timeline menu let you zoom into and out of the timeline to see additional detail.

^^^^^^^^^^^^^^^^^^
Keyboard Shortcuts
^^^^^^^^^^^^^^^^^^

There are a number of keyboard shortcuts to make it easier to navigate the timeline:

===========================  ==========================================
Key                          Action
===========================  ==========================================
:kbd:`Cmd/Ctrl-Left arrow`   Go to beginning of the timeline
:kbd:`Page down`             Move back one window's width
:kbd:`Left arrow`            Move back one tenth of the window's width
:kbd:`Right arrow`           Move ahead one tenth of the window's width
:kbd:`Page up`               Move ahead one window's width
:kbd:`Cmd/Ctrl-Right arrow`  Go to the end of the timeline
:kbd:`Down arrow`            Zoom in
:kbd:`Up arrow`              Zoom out
:kbd:`Cmd/Ctrl-Up arrow`     Zoom all the way out
===========================  ==========================================

--------
Playback
--------

Tempo can playback video and audio files together.  While the audio can be reproduced quite reliably, video tends to play back slowly in Tempo.  Certain video formats work better than others but Tempo can display video at about 15 frames per second in the best case.  To work around this and to allow finer tuned browsing of video Tempo allows you to play back at faster or slower speeds.  Play back can also be done in reverse to easily rewind and rewatch sections of video.

^^^^^^^^^^^^^^^^^^
Keyboard Shortcuts
^^^^^^^^^^^^^^^^^^

There are a few keyboard shortcuts for playback:

==================  ==========================================
Key                 Action
==================  ==========================================
:kbd:`Space`        Play forwards or stop play back
:kbd:`Shift-Space`  Play backwards or stop play back
:kbd:`Cmd/Ctrl-1`   Play at regular speed
:kbd:`Cmd/Ctrl-2`   Play at half speed
==================  ==========================================
