classdef VariableContrastNoise < edu.washington.riekelab.protocols.RiekeLabProtocol
    properties
        led                             % Output LED
        preTime = 100                   % Time before noise (ms)
        firstStimTime = 3000            % Noise duration with first stdev (ms)
        secondStimTime = 3000           % Noise duration with second stdev (ms)
        tailTime = 100                  % Time after noise (ms)
        lightMean = 0.1                 % Noise and LED background mean (V or norm. [0-1] depending on LED units)
        firstStdv = 0.005               % First noise standard deviation, post-smoothing (V or norm. [0-1] depending on LED units)
        secondStdv = 0.005               % First noise standard deviation, post-smoothing (V or norm. [0-1] depending on LED units)
        frequencyCutoff = 60            % Noise frequency cutoff for smoothing (Hz)
        numberOfFilters = 4             % Number of filters in cascade for noise smoothing
        useRandomSeed = false           % Use a random seed for each standard deviation multiple?
        amp                             % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary amplifier
    end
    
    properties 
        numberOfAverages = uint16(5)    % Number of families
        interpulseInterval = 0          % Duration between noise stimuli (s)
    end
        
    properties (Hidden)
        ledType
        ampType
    end
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, name);
            
            if strncmp(name, 'amp2', 4) && numel(obj.rig.getDeviceNames('Amp')) < 2
                d.isHidden = true;
            end
        end
        
        function p = getPreview(obj, panel)
            p = symphonyui.builtin.previews.StimuliPreview(panel, @()createPreviewStimuli(obj));
            function s = createPreviewStimuli(obj)
                s = cell(1, obj.pulsesInFamily);
                for i = 1:numel(s)
                    if ~obj.useRandomSeed
                        seed = 0;
                    elseif mod(i - 1, obj.repeatsPerStdv) == 0
                        seed = RandStream.shuffleSeed;
                    end
                    s{i} = obj.createLedStimulus(i, seed);
                end
            end
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
                obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp));
                obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
                    'baselineRegion', [0 obj.preTime], ...
                    'measurementRegion', [obj.preTime obj.preTime+obj.firstStimTime+obj.secondStimTime]);
                obj.showFigure('edu.washington.riekelab.figures.ProgressFigure', obj.numberOfAverages)
            else
                obj.showFigure('edu.washington.riekelab.figures.DualResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualMeanResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, obj.rig.getDevice(obj.amp2), {@mean, @var}, ...
                    'baselineRegion1', [0 obj.preTime], ...
                    'measurementRegion1', [obj.preTime obj.preTime+obj.stimTime], ...
                    'baselineRegion2', [0 obj.preTime], ...
                    'measurementRegion2', [obj.preTime obj.preTime+obj.stimTime]);
            end
            
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(obj.lightMean, device.background.displayUnits);
        end
        
        function [stim] = createLedStimulus(obj, seed)
            
            % generate a stimulus with two generators
            % make the first noise stimulus
            gen1 = edu.washington.riekelab.stimuli.GaussianNoiseGeneratorV2();
            gen1.preTime = obj.preTime;
            gen1.stimTime = obj.firstStimTime;
            gen1.tailTime = obj.secondStimTime + obj.tailTime;
            gen1.stDev = obj.firstStdv;
            gen1.freqCutoff = obj.frequencyCutoff;
            gen1.numFilters = obj.numberOfFilters;
            gen1.mean = obj.lightMean;
            gen1.seed = seed;
            gen1.sampleRate = obj.sampleRate;
            gen1.units = obj.rig.getDevice(obj.led).background.displayUnits;
            if strcmp(gen1.units, symphonyui.core.Measurement.NORMALIZED)
                gen1.upperLimit = 1;
                gen1.lowerLimit = 0;
            else
                gen1.upperLimit = 10.239;
                gen1.lowerLimit = -10.24;
            end
            
            stim1 = gen1.generate();
            
            % make the second noise stimulus
            gen2 = edu.washington.riekelab.stimuli.GaussianNoiseGeneratorV2();
            gen2.preTime = obj.preTime + obj.firstStimTime;
            gen2.stimTime = obj.secondStimTime;
            gen2.tailTime = obj.tailTime;
            gen2.stDev = obj.secondStdv;
            gen2.freqCutoff = obj.frequencyCutoff;
            gen2.numFilters = obj.numberOfFilters;
            gen2.mean = 0;
            gen2.seed = seed;
            gen2.sampleRate = obj.sampleRate;
            gen2.units = obj.rig.getDevice(obj.led).background.displayUnits;
            if strcmp(gen2.units, symphonyui.core.Measurement.NORMALIZED)
                gen2.upperLimit = 1 - obj.lightMean;
                gen2.lowerLimit = 0;
            else
                gen2.upperLimit = 10.239 - obj.lightMean;
                gen2.lowerLimit = -10.24;
            end
            
            stim2 = gen2.generate();
            
            % sum them into one stimulus
            sumGen = symphonyui.builtin.stimuli.SumGenerator();
            sumGen.stimuli = {stim1, stim2};
            stim = sumGen.generate(); 
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            persistent seed;
            if ~obj.useRandomSeed
                seed = 0;
            else
                seed = RandStream.shuffleSeed;
            end

            stim = obj.createLedStimulus(seed);

            epoch.addParameter('seed', seed);
            epoch.addStimulus(obj.rig.getDevice(obj.led), stim);
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
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

