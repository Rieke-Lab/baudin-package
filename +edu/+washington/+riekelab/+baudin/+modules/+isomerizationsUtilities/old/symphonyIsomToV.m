function voltage = symphonyIsomToV(deviceCalibration, deviceCalibrationDataPath, ...
    photoreceptorType, NDFs, species, ledSetting, isomerizations)

% this function will convert isomerizations to volts for a given cell/LED
% pairing with a given set of settings/NDFs (from epochGroup object)

% This function is defined below and will throw an error if the inputs are
% not sufficient to perform the necessary calculation
checkForErrorsInInput(deviceCalibration, ...
    deviceCalibrationDataPath, ...
    photoreceptorType, ...
    isomerizations);

device = compileDeviceData(ledSetting, ...
    deviceCalibration, ...
    deviceCalibrationDataPath);

photoreceptor = compilePhotoreceptorData(species, ...
    photoreceptorType);


% parse through NDFs - get attentuation factor (scale of 0 to 1, with 0 
% total attenuation);
ndfAttenuation = parseNDFEntry(NDFs, device);

% calculate isomerizations per watt for given device/photoreceptor pair
% (before NDFs) - this is isomerizations in the cell per watt of power
% arriving at the cell
isomPerW = calcIsomPerW(device.spectrum, photoreceptor.spectrum);

% account for NDFs
isomPerW = isomPerW * ndfAttenuation;

% get the number of watts that will be necessary to achieve desired
% isomerization rate
wattsNeeded = isomerizations/isomPerW;

% calibration values are in (nanowatts/volt)/(square micron); collecting area
% should be in units of square microns, so microwatts/volt seen by the given
% photoreceptor should be (calibration value) * (collecting area)
nanoWattsPerVolt = device.calibration * photoreceptor.collectingArea;

wattsPerVolt = nanoWattsPerVolt * (10^-9);

% calculate the voltage necessary
voltage = wattsNeeded/wattsPerVolt; 
    function photoreceptorStruct = compilePhotoreceptorData(species, ...
            photoreceptorType)
        photoreceptorSpectraBasePath = ...
            [calibrationDataPath filesep 'photoreceptors'];
        % get info about photoreceptor that will be useful
        photoreceptorStruct.species = species;
        photoreceptorStruct.type = photoreceptorType;
        % load photoreceptor data
        [photoreceptorStruct.spectrum.wavelengths, photoreceptorStruct.spectrum.values] = ...
            readSpectrum([photoreceptorSpectraBasePath filesep species filesep photoreceptorType filesep 'spectrum.txt']);
        photoreceptorStruct.collectingArea = ...
            readCollectingArea([photoreceptorSpectraBasePath filesep species filesep photoreceptorType filesep 'collectingArea.txt']);
    end

    function devStruct = compileDeviceData(ledSetting, ...
            deviceCalibration, ...
            deviceCalibrationDataPath)
        
        % get info about device that will be useful
        devStruct.setting = ledSetting;
        % parse through deviceCalibrationDataPath to get rig and name
        [folderPath, devStruct.name, ~] = fileparts(deviceCalibrationDataPath);
        folders = strsplit(folderPath, filesep);
        devStruct.rig = folders{end};
        % load device data
        [devStruct.spectrum.wavelengths, devStruct.spectrum.values] = readSpectrum([deviceCalibrationDataPath filesep 'spectrum.txt']);
        devStruct.calibration = deviceCalibration;
        devStruct.path = deviceCalibrationDataPath;
    end

    function checkForErrorsInInput(deviceCalibration, deviceCalibrationDataPath, photoreceptorType, isomerizations)
        % check inputs, if there is an issue, return an error
        if ~isnumeric(deviceCalibration)
            error(['The device calibration value provided to symphonyIsomToV must be '...
                ' a numeric value.']);
        else
            if deviceCalibration < 0
                error(['The device calibration value provided to symphonyIsomToV '...
                    'must be a positive numeric value.']);
            end
        end
        if ~exist(deviceCalibrationDataPath, 'file')
            error(['The deviceCalibrationDataPath provided to symphonyIsomToV '...
                'does not point to a valid file.']);
        end
        if ~ischar(photoreceptorType)
            error(['The photoreceptorType provided to symphonyIsomToV must be a string '...
                'that specifies a photoreceptor type for the current species.']);
        end
        if ~isnumeric(isomerizations)
            error('The isomerization rate provided to symphonyIsomToV must be numeric.');
        else
            if isomerizations < 0
                error(['The isomerization rate provided to symphonyIsomToV must be '...
                    'a positive numeric value.']);
            end
        end
    end

end
