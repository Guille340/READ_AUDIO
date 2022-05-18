%  [y,varargout] = READAUDIOFILE(fpath,channel,samples,numClass,varargin)
%
%  DESCRIPTION: reads a range of SAMPLES(2) consecutive samples from an
%  audio file FPATH and audio track CHANNEL. The output values are given
%  as signed integer or floating point according to NUMCLASS, with the
%  lowest possible number of bits. Only 'WAV' format (PCM,44 byte header)
%  and 'RAW' audio format (PCM, headless) are supported.
%
%  INPUT VARIABLES
%  - fpath [string]: absolute path of audio file
%  - channel [integer number]: selected audio channel. Use ¦channel¦ = []
%    to read all channels.
%  - samples [firstSample numSamples]: section of the audio file to be
%    read. The first element is the starting audio sample (firstSample =
%    1,2,...) and the second element the number of samples to be read.
%  - numClass [string]: numeric class for the output audio samples ¦y¦.
%    The number of bits for the class (8, 16, 32, 64) will be the lowest
%    that can represent the bit depth of the audio data (e.g. for 24bit
%    audio, ¦y¦ is given as 'single' class for ¦numClass¦ = 'float').
%    Two options for ¦numClass¦:
%    ¬ 'int': signed integer
%    ¬ 'float': floating point number
%  - sampleRate (varargin{1}) [number]: sampling rate (RAW).
%  - numChannels (varargin{2}) [integer number]: number of channels (RAW).
%  - bitsPerSample (varargin{3}) [integer number]: bit resolution (RAW).
%  - byteOrder (varargin{4}) [integer number]: endianess (RAW).
%
%  OUTPUT VARIABLES
%  - y [numeric vector/array]: audio samples, with one column per channel.
%  - yinfo (varargout{1}) [structure]: information of audio file. The
%    structure contains 4 fields:
%    ¬ sampleRate (varargin{1}) [number]: sampling rate [Hz]
%    ¬ numChannels (varargin{2}) [integer number]: number of channels.
%    ¬ bitsPerSample (varargin{3}) [integer number]: bit resolution
%      (¦bitsPerSample¦ = 8*2n, 1, 2...8). It may be different than the
%      number of bits of the numeric class.
%    ¬ byteOrder (varargin{4}) [string]: endianess. Two options:
%      'l': little endian
%      'b': big endian
%
%  INTERNALLY CALLED FUNCTIONS
%  - readwavHeader
%
%  CONSIDERATIONS & LIMITATIONS
%  - WAV files with a corrupted file size in the header can still be read
%    (i.e. subchunk2size =  0). A corrupted header is common when the
%    file suddlenly closes (e.g. power off, malfunctioning acquisition
%    software).
%  - Only uncrompressed, PCM data is supported (i.e. RAW and WAV).
%  - Either one or all channels can be read, but nothing in between.
%
%  FUNCTION CALLS
%  1) y = readAudioFile(fpath,channel,samples,numClass)
%     - Only for 'WAV' format
%
%  2) [y,yinfo] = readAudioFile(fpath,channel,samples,numClass,sampleRate,
%                 numChannels,bitsPerSample,byteOrder)
%     - Only for 'RAW' format
%
%  REFERENCES
%  - http://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/WAVE/WAVE.html
%  - http://soundfile.sapp.org/doc/WaveFormat/
%
%  See also READWAVHEADER

%  VERSION 1.2
%  Date: 25 Mar 2021
%  Author: Guillermo Jimenez Arranz
%  - Fixed error that occurred when the start sample is lower than 1.
%
%  VERSION 1.1
%  Date: 19 Mar 2021
%  Author: Guillermo Jimenez Arranz
%  - Fixed error that occurred when the start sample is not an integer
%    number with ROUND(SAMPLES).
%
%  VERSION 1.0
%  Guillermo Jimenez Arranz
%  email: gjarranz@gmail.com
%  06 Apr 2018

function [y,varargout] = readAudioFile(fpath,channel,samples,numClass,varargin)

[~,~,fext] = fileparts(fpath);

% Retrieve Audio Settings
switch fext
    case {'.3gp','.aa','.aac','.aax','.act','.aiff','.amr','.ape',... % Unsupported audio formats
            '.au','.awb','.dct','.dss','.dvf','.flac','.gsm','.iklax',...
            '.ivs','.m4a','.m4b','.m4p','.mmf','.mp3','.mpc','.msv',...
            '.ogg','.oga','.mogg','.opus','.ra','.rm','.sln','.tta',...
            '.vox','.wma','.wv','.webm','.8svx'}
        error('Audio format not supported')

    case '.wav' % WAV audio format (PCM)
        % Error Control: Number of Input Arguments
        narginchk(4,8)
        if nargin > 4 && nargin < 8
            error('Wrong number of input arguments'); 
        end

        % Read WAV header
        wavHeader = readwavHeader(fpath);

        % Uncompressed audio files only format supported
        if ~strcmp(wavHeader.fmt,'WAVE') || ~wavHeader.audioFormat
            error('File format not supported')
        end

        % Read WAV files with data size mismatch
        fstats = dir(fpath);
        dataSize = wavHeader.subchunk2size;
        % subchunk2size = 0 indicates WAV file did not close properly (corrupt)
        if ~wavHeader.subchunk2size 
            dataSize = floor((fstats.bytes-44)/wavHeader.blockAlign)...
                *wavHeader.blockAlign; % size of audio data (full all-channel samples) [bytes]
            warning(['Size of audio data disagrees with header information:' ...
                ' file possibly corrupted. The audio data will be imported']);
        end

        % Audio format parameters
        headerOffset = wavHeader.startByte - 1; % start of audio data [bytes]
        nch = wavHeader.numChannels;
        fs = wavHeader.sampleRate;
        nbit = wavHeader.bitsPerSample;

        if strcmp(wavHeader.chunkID,'RIFF') % 'RIFF' string
            en = 'l'; % little-endian
        else % 'RIFX' string
            en = 'b'; % big-endian
        end

    otherwise % RAW audio format ('.raw' or any other extension not included above)
        % Error Control: Number of Input Arguments
        if nargin < 8, error('Not enough input arguments'); end
        if nargin > 8, error('Too many input arguments'); end

        % Audio format parameters
        fstats = dir(fpath);
        dataSize = fstats.bytes;
        headerOffset = 0; % start of audio data [bytes]
        fs = varargin{1};
        nch = varargin{2};
        nbit = varargin{3};
        en = varargin{4};
end

% Error Control: Maximum Number of Channels
if ~isempty(channel)
    if (channel > nch) || (length(channel) > 1)
        error('The selected channel exceeds the number of channels available')
    end
end

% Error Control: Valid Options for ¦nbit¦
if ~any(nbit == [8 16 24 32 40 48 56 64])
    error('Bit resolution of audio file not supported')
end

% Determine the Section of Audio to be Read
allSamples = dataSize*8/(nbit*nch);
if ~isempty(samples)
    firstSample = round(samples(1)); % first audio sample to read
    numSamples = round(samples(2)); % total number of audio samples to read
    lastSample = firstSample + numSamples - 1;
    % Error Control: First sample is lower than 1
    if firstSample < 1
        firstSample = 1;
        warning(['The index of the first sample must be equal or higher '...
            'than 1'])
    end
    % Error Control: Selected section is completely out of bounds
    if firstSample > allSamples
        error(['The index of the first sample exceeds the number of '...
            'samples in the audio file'])
    end
    % Error Control: Selected section is partially out of bounds
    if lastSample > allSamples
        numSamples = allSamples - firstSample + 1;
        warning(['The end of the audio file was reached - only the first '...
            'part of the selected audio will be processed'])
    end
else
    firstSample = 1;
    numSamples = allSamples;
end

% Generate the precision string (see #fread)
if nbit > 32, floatClass = 'double'; else, floatClass = 'single'; end
validClass = any(nbit == [8 16 32 64]);
if validClass  % true if a numeric class is available for ¦nbit¦ bits
    switch numClass
        case 'int'
            strprec = sprintf('*int%d',nbit);
        case 'float'
            strprec = sprintf('int%d=>%s',nbit,floatClass);
    end
else
    switch numClass
        case 'int'
            strprec = sprintf('bit%d=>int%d',nbit,2^ceil(log2(nbit)));
        case 'float'
            strprec = sprintf('bit%d=>%s',nbit,floatClass);
    end
end

% Parameters for #fread (One/All Channels)
if ~isempty(channel) % read one channel
    channelOffset = (channel-1)*nbit/8;
    if ~validClass
        skipfct = 8; 
    else
        skipfct = 1; % for NBIT ~= 8,16,32,64 the skip value is expressed in bits (not bytes)
    end 
    skip = (nch-1)*nbit/8 * skipfct;
    M = 1;
else % read all channels
    channelOffset = 0;
    skip = 0;
    M = nch;
end

% Parameters for #fread (Selected/All Samples)
if ~isempty(samples) % read a given set of samples
    sampleOffset = (firstSample-1)*nch*nbit/8;
    N = numSamples;
else % read all samples
    sampleOffset = 0;
    N = dataSize*8/(nch*nbit);
end

% Read Audio File
foffset = headerOffset + channelOffset + sampleOffset;
fid = fopen(fpath,'r',en);
fseek(fid,foffset,'bof');
y = fread(fid,[M N],strprec,skip)';
fclose(fid);

% Save Audio Information
if strcmp(fext,'.wav') && nargout == 2
    yinfo.numChannels = nch;
    yinfo.sampleRate = fs;
    yinfo.bitsPerSample = nbit;
    yinfo.byteOrder = en;
    varargout{1} = yinfo;
end

