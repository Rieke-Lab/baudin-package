function voltage = SymphonyIsomerizationsConverter( ...
    deviceCalibration, ...
    photoreceptorSpectrum, ...
    deviceSpectrum, ...
    NDFs, ...
    isomerizations)

% this function will convert isomerizations to volts for a given cell/LED
% pairing with a given set of settings/NDFs (from epochGroup object)

device.wavelengths = deviceSpectrum(:, 1);
device.values = deviceSpectrum(:, 2);

photoreceptor.wavelengths = photoreceptorSpectrum(:, 1);
photoreceptor.values = photoreceptorSpectrum(:, 2);

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
nanoWattsPerVolt = deviceCalibration * photoreceptor.collectingArea;

wattsPerVolt = nanoWattsPerVolt * (10^-9);

% calculate the voltage necessary
voltage = wattsNeeded/wattsPerVolt; 

end
