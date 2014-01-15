=========
Analyzing
=========

Tempo comes with tools for automatically detecting features in audio files.  Currently there are tools for detecting fly song and mouse vocalization.  To run one of the tools choose :menuselection:`Edit -> Detect Features` or click the equivalent icon on the toolbar.  

--------
Fly Song
--------

This detector can find sine and pulse song in audio recordings of Drosophila.  It is based on the FlySongSegmenter software published in:

	Arthur et al.: Multi-channel acoustic recording and automated analysis of Drosophila courtship songs. BMC Biology 2013 11:11

and available at <http://github.com/FlyCourtship/FlySongSegmenter>.

------------------
Mouse Vocalization
------------------

This detector can find vocalizations in audio recordings of mice.  It is based on the Ax software published in:

	???

and available at ???.

------------
Pulse Trains
------------

This detector can find repeated sequences of features in other sets of features.  Each "train" that is found has a minimum number of repeats and a maximum time between each feature within the train.  For example, it can find a minimum of ten fly song pulses in a row, no more than 0.1 seconds apart.  Typically it is used to detect trains of pulses from fly song but can be used in other contexts.
