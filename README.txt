Read Audio Files
=======================

MATLAB code for reading WAVE files and their heading information. 

Compared to audioread, readAudioFile has the advantage that files with a corrupt
header (such as those stored by PAMGuard after a software crash) can still be 
read. The function allows the user to select the channel(s) and section the 
audio file to read.

To use this toolbox with your code simply execute the command ADDPATH(FPATH), 
where FPATH is the absolute path of the toolbox.

[Guillermo Jiménez Arranz, 16 Jun 2021]





