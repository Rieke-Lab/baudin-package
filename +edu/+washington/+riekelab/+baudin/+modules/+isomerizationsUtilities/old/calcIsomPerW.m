% deviceSpectrum - struct with .values, .wavelengths (in m or nm)
% photoreceptorSpectrum - struct with .values, .wavelengths (in m or nm)

function isom = calcIsomPerW(deviceSpectrum, photoreceptorSpectrum)

% Planck's constant
h = 6.62607004e-34; % m^2*kg/s
% Speed of light
c = 299792458; % m/s

% For both spectra, if the wavelengths are in nanometers, convert them to
% meters (this assumes that it will only be in nm or m). 
if (max(photoreceptorSpectrum.wavelengths) > 1)
    photoreceptorSpectrum.wavelengths = photoreceptorSpectrum.wavelengths * (10^-9);
end
if (max(deviceSpectrum.wavelengths) > 1)
    deviceSpectrum.wavelengths = deviceSpectrum.wavelengths * (10^-9);
end

% The device spectra are often much more finely sampled than the
% photoreceptor spectra.  Resample the device spectra at only those
% wavelengths for which there is a probability of absorption.  
deviceSpectrum.values = ...
    interp1(deviceSpectrum.wavelengths, deviceSpectrum.values, photoreceptorSpectrum.wavelengths);
deviceSpectrum.wavelengths = photoreceptorSpectrum.wavelengths;

% Calculate the change in wavelength for each bin. Assume that the last bin
% is of size equivalent to the second to last.
dLs = deviceSpectrum.wavelengths(2:end) - deviceSpectrum.wavelengths(1:end-1);
dLs(end+1) = dLs(end);

% Calculate the isomerizations per joule of energy from the device (or,
% equivalently, isomerizations per second per watt from the device).  Do so
% with:
    % isom = integral(deviceSpectrum*photoreceptorSpectrum*dLs) / 
    %        integral(deviceSpectrum*(hc/wavelengths)*dLs)
isom = ((deviceSpectrum.values .* photoreceptorSpectrum.values) * dLs') / ...
    ((deviceSpectrum.values .* (h*c ./ deviceSpectrum.wavelengths)) * dLs');