function voltage = symphonyIsomToV( ...
    deviceCalibration, ...
    photoreceptorSpectrum, ...
    deviceSpectrum, ...
    photoreceptorType, ...
    NDFs, ...
    species, ...
    ledSetting, ...
    isomerizations)

% this function will convert isomerizations to volts for a given cell/LED
% pairing with a given set of settings/NDFs (from epochGroup object)

% This function is defined below and will throw an error if the inputs are
% not sufficient to perform the necessary calculation
checkForErrorsInInput(deviceCalibration, ...
    photoreceptorType, ...
    isomerizations);

device = compileDeviceData(ledSetting, ...
    deviceCalibration, ...
    deviceSpectrum);

photoreceptor = compilePhotoreceptorData(species, ...
    photoreceptorType, ...
    collectingArea, ...
    photoreceptorSpectrum);


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
            photoreceptorType, ...
            collectingArea, ...
            photoreceptorSpectrum)

        % get info about photoreceptor that will be useful
        photoreceptorStruct.species = species;
        photoreceptorStruct.type = photoreceptorType;
        photoreceptorStruct.wavelengths = photoreceptorSpectrum(:, 1);
        photoreceptorStruct.values = photoreceptorSpectrum(:, 2);
        photoreceptorStruct.collectingArea = collectingArea;
    end

    function devStruct = compileDeviceData(ledSetting, ...
            deviceCalibration, ...
            deviceSpectrum)
        
        % get info about device that will be useful
        devStruct.setting = ledSetting;
        devStruct.wavelengths = deviceSpectrum(:, 1);
        devStruct.values = deviceSpectrum(:, 2);
        devStruct.calibration = deviceCalibration;

    end

    function checkForErrorsInInput(deviceCalibration, photoreceptorType, isomerizations)
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
