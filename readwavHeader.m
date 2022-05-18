%  wavHeader = READWAVHEADER(filePath)
%
%  DESCRIPTION
%  Reads the header of a WAVE (*.wav) audio file, which consists in 44 bytes 
%  containing 13 fields with information on the format and size of the audio 
%  file.
%
%  INPUT VARIABLES
%  - filePath: full path of the audio file.
%
%  OUTPUT VARIABLES
%  - wavHeader: structure containing the 13 fields of a *.wav file:
%    ¬ chunkID: letters "RIFF" in ASCII format (0x52494646) [char, 4 bytes]
%    ¬ chunksize: number of bytes after this field, including header and
%      audio data (i.e. 36 + subchunk2size [bytes]) [uint32, 4 bytes]
%    ¬ fmt: file format, given by four letters in ASCII format. "WAVE" for
%      *.wav files (0x57415645) [char, 4 bytes]
%    ¬ subchunk1ID: letters "fmt" in ASCII format. ¦subchunk1id¦ defines
%      the start of the Data Format Subchunk, which describes the format of
%      the audio data [char, 4 bytes]
%    ¬ subchunk1size: number of bytes within the current subchunk after
%      this field. ¦subchunk1size¦ = 16 for PCM (Pulse Code Modulated)
%      audio signal [uint32, 4 bytes]
%    ¬ audioformat: integer describing the format of the audio file.
%      ¦audioformat¦ = 1 for PCM and values other than 1 indicate some
%      form of compression [uint16, 2 bytes]
%    ¬ numchannels: number of channels in the audio file (1 = mono, 2 =
%      stereo, etc) [uint16, 2 bytes]
%    ¬ samplerate: sampling rate [Hz] [uint32, 4 bytes]
%    ¬ byterate: data rate [bytes s-1]. ¦byterate¦ = samplerate *
%      numchannels * bytespersample / 8 [uint32, 4 bytes]
%    ¬ blockalign: number of bytes per sample, including all channels.
%     ¦blockalign¦ = numchannels * bitspersample / 8 [uint16, 2 bytes]
%    ¬ bitspersample: number of bits per sample and channel [uint16,
%      2 bytes]
%    ¬ subchunk2ID: letters "data" in ASCII format. ¦subchunk2id¦ defines
%      the start of the Audio Data [char, 4 bytes]
%    ¬ subchunk2size: number of bytes of Audio Data (equal to the number
%      of bytes within the current subchunk after this field)
%     ¦subchunk2size¦ = numsamples * numchannels * bitspersample / 8
%     [uint32, 4 bytes]
%    ¬ byteOrder: endianness ('l' for little-endian, 'b' for big-endian)
%
%  INTERNALLY CALLED FUNCTIONS
%  - None
%
%  COMMENTS ON RIFF FILES
%  - RIFF (Resource Interchange File Format) is a format for the storage
%    of various types of data, including bitmaps, audio, video and device
%    control information. The type of data is indicated by the file
%    extension. Some common RIFF file types are:
%    ¬ WAV (Windows audio)
%    ¬ AVI (Windows audiovisual)
%    ¬ RDI (Bitmapped data)
%    ¬ RMI (Windows "RIFF MIDIfile")
%    ¬ RMN (Multimedia movie)
%    ¬ CDR (CorelDRAW vector graphics file)
%    ¬ ANI (Animated Windows cursors)
%    ¬ PAL (Palette)
%    ¬ DLS (Downloadable Sounds)
%    ¬ WebP (An image format developed by Google)
%    ¬ XMA (Microsoft Xbox 360 console audio format based on WMA Pro)
%  - The default byte ordering for WAVE data files is little-endian. Files
%    written using big-endian have the identifier RIFX instead of RIFF.
%  - 8-bit samples are stored as unsigned bytes, ranging from 0 to 255.
%    16-bit samples are stored as 2's-complement signed integers, ranging
%    from -32768 to 32767.
%  - There may be additional subchunks in a Wave data stream. If so, each
%    will have a char[4] ¦subchunkID¦, and uint32 ¦subchunksize¦, and
%    ¦subchunksize¦ amount of data.
%
%  CONSIDERATIONS AND LIMITATIONS
%  - In a wav file the data is stored using little-endian byte ordering
%    scheme. The character fields (fmt, subchunk1id, subchunk2id) may
%    appear to be stored as big-endian but in reality each byte is treated
%    individually as uint8 (each uint8 value is a letter).
%
%  REFERENCES
%  - http://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/WAVE/WAVE.html
%  - http://soundfile.sapp.org/doc/WaveFormat/
%
%  See also READAUDIOFILE

%  VERSION 1.0
%  Guillermo Jimenez Arranz
%  email: gjarranz@gmail.com
%  24 Jan 2018

function wavHeader = readwavHeader(filePath)

% Read WAV Header
fid = fopen(filePath,'r');
header = fread(fid,44,'*uint8');

% RIFF/RIFX Identifier
chunkID = char(header(1:4))'; % string 'RIFF' (little-endian) or 'RIFX' (big-endian)

switch chunkID
    case 'RIFF'
        % RIFF Chunk Descriptor
        chunkSize = double(typecast(header(5:8),'uint32'));
        fmt = char(header(9:12))'; % string for file format ('WAVE')

        % Subchunk 1 - Sound Data Format
        subchunk1ID = char(header(13:16))'; % string for subchunk 1 ('fmt')
        subchunk1size = double(typecast(header(17:20),'uint32'));
        audioFormat = double(typecast(header(21:22),'uint16'));
        numChannels = double(typecast(header(23:24),'uint16'));
        sampleRate = double(typecast(header(25:28),'uint32'));
        byteRate = double(typecast(header(29:32),'uint32')); % byte rate [bytes s-1]
        blockAlign = double(typecast(header(33:34),'uint16'));
        bitsPerSample = double(typecast(header(35:36),'uint16'));

        % Subchunk 2 - Data
        startByte = 45;
        subchunk2ID = char(header(37:40))'; % string for subchunk 1 ('data')
        subchunk2size = double(typecast(header(41:44),'uint32'));
        while ~strcmp(subchunk2ID,'data') % skip unrecognised chunks (e.g. 'junk')
            fseek(fid,subchunk2size,'cof');
            header = fread(fid,8,'*uint8');
            startByte = startByte + subchunk2size + 8;
            subchunk2ID = char(header(1:4))'; % string for subchunk 1 ('data')
            subchunk2size = double(typecast(header(5:8),'uint32'));
        end
        byteOrder = 'l'; % little-endian

    case 'RIFX' % read using big-endian byte order scheme
        % RIFX Chunk Descriptor
        chunkSize = double(swapbytes(typecast(header(5:8),'uint32')));
        fmt = char(header(9:12))'; % string for file format ('WAVE')

        % Subchunk 1 - Sound Data Format
        subchunk1ID = char(header(13:16))'; % string for subchunk 1 ('fmt')
        subchunk1size = double(swapbytes(typecast(header(17:20),'uint32')));
        audioFormat = double(swapbytes(typecast(header(21:22),'uint16')));
        numChannels = double(swapbytes(typecast(header(23:24),'uint16')));
        sampleRate = double(swapbytes(typecast(header(25:28),'uint32')));
        byteRate = double(swapbytes(typecast(header(29:32),'uint32'))); % byte rate [bytes s-1]
        blockAlign = double(swapbytes(typecast(header(33:34),'uint16')));
        bitsPerSample = double(swapbytes(typecast(header(35:36),'uint16')));

        % Subchunk 2 - Data
        startByte = 45;
        subchunk2ID = char(header(37:40))'; % string for subchunk 1 ('data')
        subchunk2size = double(swapbytes(typecast(header(41:44),'uint32')));
        while ~strcmp(subchunk2ID,'data') % skip unrecognised chunks (e.g. 'junk')
            fseek(fid,subchunk2size,'cof');
            header = fread(fid,8,'*uint8');
            startByte = startByte + subchunk2size + 8;
            subchunk2ID = char(header(1:4))'; % string for subchunk 1 ('data')
            subchunk2size = double(swapbytes(typecast(header(5:8),'uint32')));
        end
        wavHeader.byteOrder = 'b'; % big-endian
end
fclose(fid); % close file

% Create WAV Header Structure
wavHeader.chunkID = chunkID;
wavHeader.chunkSize = chunkSize;
wavHeader.fmt = fmt;
wavHeader.subchunk1ID = subchunk1ID;
wavHeader.subchunk1size = subchunk1size;
wavHeader.audioFormat = audioFormat;
wavHeader.numChannels = numChannels;
wavHeader.sampleRate = sampleRate;
wavHeader.byteRate = byteRate;
wavHeader.blockAlign = blockAlign;
wavHeader.bitsPerSample = bitsPerSample;
wavHeader.subchunk2ID = subchunk2ID;
wavHeader.subchunk2size = subchunk2size;
wavHeader.startByte = startByte;
wavHeader.byteOrder = byteOrder;
