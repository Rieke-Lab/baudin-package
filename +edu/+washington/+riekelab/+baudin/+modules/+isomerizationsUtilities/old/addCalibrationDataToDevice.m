function addCalibrationDataToDevice(device, path)
% each device in symphony for which their is calibration data will need to
% contain the path of the file containing that data and the most recent
% calibration values for the device (a factor relating power to voltage for
% non-calibrated LEDs and power to intensity for calibrated LEDs and
% spatial stim device); there will be a calibration value for each setting
% on the device; the calibration values and the path will be stored as
% configuration parameters of the device object; this function will take a
% device and a path as an input; it will store the path as a configuration
% parameter, and also use iet to look up the file it points to and pull the
% most recent calibration values for each setting

% this will be done for each setting on the device

% add the calibration path
device.addConfigurationSetting('CalibrationFolder', path);

settings = getSettings(path);
for st = 1:numel(settings);
    currKey = ['CalibrationValue' settings{st}];
    [calibValue, ~] = readCalibrationValue([path filesep 'calibrations'], settings{st});
    device.addConfigurationSetting(currKey, calibValue);
end
    
    % helper methods
    function settings = getSettings(path)
        fileID = fopen([path filesep 'settings.txt.']);
        % throw away the first 3 lines (they are just the header)
        for i = 1:4
            fgetl(fileID);
        end
        
        settings = {};
        curr = fgetl(fileID);
        while curr ~= -1
            settings{end+1} = curr; %#ok<AGROW>
            curr = fgetl(fileID);
        end
       
    end

end
