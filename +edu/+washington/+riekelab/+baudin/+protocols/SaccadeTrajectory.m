classdef SaccadeTrajectory < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Presents a saccade trajectory taken from a natural scene.
    
    properties
        led                             % Output LED
        preTime = 10                    % Leading duration (ms)
        tailTime = 400                  % Trailing duration (ms)
        
        trajectory                      % The trajectory to show
        trajectoryMaxContrast           % Contrast of highest point on trajectory
        
        lightBaseline = 0               % LED background mean (V or norm. [0-1] depending on LED units)
        amp                             % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary amplifier
    end
    
    properties
        numberOfAverages = uint16(5)    % Number of epochs
        interpulseInterval = 0          % Duration between pulses (s)
    end
    
    properties (Hidden)
        ledType
        ampType
        
        SACCADE_TRAJECTORY_FOLDER = '';
        trajectoryNames
        
        trajectoryType = symphonyui.core.PropertyType('cellstr', 'row', obj.trajectoryNames);
    end
    
    methods
        
        function didSetRig(obj)            
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            % load the possible saccade trajectories
            obj.GetSaccadeTrajectoryList();
            
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function GetSaccadeTrajectoryList(obj)
            files = dir([obj.SACCADE_TRAJECTORY_FOLDER filesep '*.txt']);
            obj.trajectoryNames = cell(1, numel(files));
            for i = 1:numel(files)
               obj.trajectoryNames{i} = files.name; 
            end
        end
        
        function trajPath = TrajectoryNameToPath(obj, trajName)
            trajPath = [obj.SACCADE_TRAJECTORY_FOLDER filesep trajName]; 
        end
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, name);
            
            if strncmp(name, 'amp2', 4) && numel(obj.rig.getDeviceNames('Amp')) < 2
                d.isHidden = true;
            end
        end
        
        function p = getPreview(obj, panel)
            [times, durations, amps] = ...
                obj.LoadSaccadeTrajectory();
            
            p = ...
                symphonyui.builtin.previews.StimuliPreview(panel, @()obj.createLedStimulus(times, durations, amps));
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure( ...
                    'symphonyui.builtin.figures.ResponseFigure', ...
                    obj.rig.getDevice(obj.amp));
                obj.showFigure( ...
                    'symphonyui.builtin.figures.MeanResponseFigure', ...
                    obj.rig.getDevice(obj.amp));
            else
                obj.showFigure( ...
                    'edu.washington.riekelab.figures.DualResponseFigure', ...
                    obj.rig.getDevice(obj.amp), ...
                    obj.rig.getDevice(obj.amp2));
                obj.showFigure( ...
                    'edu.washington.riekelab.figures.DualMeanResponseFigure', ...
                    obj.rig.getDevice(obj.amp), ...
                    obj.rig.getDevice(obj.amp2));
            end
            
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement( ...
                obj.lightBaseline, ...
                device.background.displayUnits);
        end
        
        function stim = createLedStimulus(obj, times, durations, amps)
            gen = symphonyui.builtin.stimuli.SaccadeTrajectoryGenerator();
            
            gen.preTime = obj.preTime;
            gen.tailTime = obj.tailTime;
            
            gen.trajectoryMaxContrast = obj.trajectoryMaxContrast;
            
            gen.fixationTimes = times;
            gen.fixationDurations = durations;
            gen.amplitudes = amps;
            
            gen.baseline = obj.lightBaseline;
            
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
            
            stim = gen.generate();
        end
        
        function [fixationTimes, fixationDurations, amplitudes] = ...
                LoadSaccadeTrajectory(obj)
            if exist(obj.trajectoryFilePath, 'file')
                trajParams = dlmread(obj.trajectoryFilePath);
                fixationTimes = trajParams(:, 1)';
                fixationDurations = trajParams(:, 2)';
                amplitudes = trajParams(:, 3)';
            else
                errStr = ['The provided path: ' obj.trajectoryFilePath ...
                    ' for the saccade trajectory file cannot be found.'];
                error(errStr);
            end
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            [times, durations, amps] = ...
                obj.LoadSaccadeTrajectory();
            
            epoch.addStimulus( ...
                obj.rig.getDevice(obj.led), ...
                obj.createLedStimulus(times, durations, amps));
            
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end

            % Store some necessary stimulus info
            epoch.addParameter(...
                'fixationTimes', times);
            epoch.addParameters(...
                'fixationDurations', durations);
            epoch.addParameter( ...
                'amplitudes', amps);
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.led);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
        
        function a = get.amp2(obj)
            amps = obj.rig.getDeviceNames('Amp');
            if numel(amps) < 2
                a = '(None)';
            else
                i = find(~ismember(amps, obj.amp), 1);
                a = amps{i};
            end
        end
        
    end
    
end