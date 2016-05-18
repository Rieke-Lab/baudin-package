function attenuation = parseNDFEntry(NDFs, device)
% this function will parse through a series of NDF entries that are
% in elements of a cell array (each of which identifies a specific NDF in a
% manner that will allow its attenuation to be looked up within a table)
% the device input argument is a structure that contains the fields: rig,
% name, and setting; these values will be necessary to look up the
% attenuation for a given NDF (because the NDFs are not spectrally flat)

% this function assumes that NDF attenutations can be combined
% multiplicatively
if isempty(NDFs)
    attenuation = 1;
else
    % load the ndf data (this will load a map that will contain the ndf
    % attenuation factors for all ndfs associated with a given device; each of the
    % different ndfs will be accessible through the appropriate key (which will
    % be the entries in the input argument 'NDFs' cell array); the values for
    % each of these keys will be attenuation factors
    if ischar(device)
        ndfData = readNDFList([device filesep 'ndfs.txt']);
    else
        ndfData = readNDFList([device.path filesep 'ndfs.txt']);
    end
    
    % create an attenuation value (value will be the attenuation factor on a
    % base 10 logarithmic scale);
    attenuation = 0;
    for ndf = 1:numel(NDFs)
        % get data for specific NDF
        ndfKey = NDFs{ndf};
        if ndfData.isKey(NDFs{ndf})
            currentNDFAttenuation = ndfData(ndfKey);
            % add this to the attenuation variable (because ndfs assumed to combine
            % multiplicatively, so must add to this logarithmic value)
            attenuation = attenuation + currentNDFAttenuation;
        else
            str = ['The NDF entry: ' ndfKey ' could not be matched with any ' ...
                'calibrated NDFs. Please enter a valid NDF identifier.'];
            error(str);
        end
    end
    
    % convert attenuation to an actual factor instead of being on a logarithmic
    % scale
    attenuation = 10^(-attenuation);
end
