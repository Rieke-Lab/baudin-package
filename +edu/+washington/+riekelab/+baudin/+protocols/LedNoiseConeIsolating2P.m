classdef LedNoiseConeIsolating2P < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Presents Gaussian noise stimuli intended to stimulate a signle cone.
    % Stimulus will have a specified mean number of isomerizations as well
    % as a noise standard deviation - also in isomerizations.
    
    properties
        redLedIsomPerVoltS = 0          % S cone isomerizations per volt delivered to red led with given settings
        redLedIsomPerVoltM = 0          % M cone isomerizations per volt delivered to red led with given settings
        redLedIsomPerVoltL = 0          % L cone isomerizations per volt delivered to red led with given settings
        blueLedIsomPerVoltS = 0         % S cone isomerizations per volt delivered to blue led with given settings
        blueLedIsomPerVoltM = 0         % M cone isomerizations per volt delivered to blue led with given settings
        blueLedIsomPerVoltL = 0         % L cone isomerizations per volt delivered to blue led with given settings
        uvLedIsomPerVoltS = 0           % S cone isomerizations per volt delivered to uv led with given settings
        uvLedIsomPerVoltM = 0           % M cone isomerizations per volt delivered to uv led with given settings
        uvLedIsomPerVoltL = 0           % L cone isomerizations per volt delivered to uv led with given settings
        preTime = 100                   % Noise leading duration (ms)
        stimTime = 600                  % Noise duration (ms)
        tailTime = 100                  % Noise trailing duration (ms)
        frequencyCutoff = 60            % Noise frequency cutoff for smoothing (Hz)
        numberOfFilters = 4             % Number of filters in cascade for noise smoothing
        meanIsomerizations = 1000       % Mean number of isomerizations for noise and background in units of isomerizations
        stdvIsomerizations = 500        % Noise standard deviation in units of isomerizations
        coneTypeToStimulate = edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolating2P.S_CONE   % Type of cone that this stimulus will isolate
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
    
    properties (Hidden, Dependent)
        pulsesInFamily
        
        rbuToLms
        lmsToRbu
        
        lmsMeanIsomerizations
        lmsStdvIsomerizations
        
        coneTypeToStimulateIndex
        
        redLed
        blueLed
        uvLed
    end
    
    properties (Hidden)
        coneTypeToStimulateType = symphonyui.core.PropertyType( ...
            'char',  ...
            'row', ...
            {edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolating2P.S_CONE, ...
            edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolating2P.M_CONE, ...
            edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolating2P.L_CONE})
        ampType
    end
    
    properties (Constant)
        RED_LED = 'Red LED';
        BLUE_LED = 'Blue LED';
        UV_LED = 'UV LED';
        
        S_CONE = 's cone';
        M_CONE = 'm cone';
        L_CONE = 'l cone';
    end
    
    methods
        
        function value = get.rbuToLms(obj)
            value = [obj.redLedIsomPerVoltL obj.blueLedIsomPerVoltL obj.uvLedIsomPerVoltL; ...
                obj.redLedIsomPerVoltM obj.blueLedIsomPerVoltM obj.uvLedIsomPerVoltM; ...
                obj.redLedIsomPerVoltS obj.blueLedIsomPerVoltS obj.uvLedIsomPerVoltS];
        end
        
        function value = get.lmsToRbu(obj)
            value = inv(obj.rbuToLms);
        end
        
        function value = get.coneTypeToStimulateIndex(obj)
            value = [];
            switch obj.coneTypeToStimulate
                case edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolating2P.L_CONE
                    value = 1;
                case edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolating2P.M_CONE
                    value = 2;
                case edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolating2P.S_CONE
                    value = 3;
            end
        end
        
        function value = get.lmsMeanIsomerizations(obj)
            value = obj.meanIsomerizations * ones(3, 1);
        end
        
        
        function value = get.lmsStdvIsomerizations(obj)
            value = zeros(3, 1);
            value(obj.coneTypeToStimulateIndex) = obj.stdvIsomerizations;
        end
        
        function value = get.redLed(obj)
            value = obj.rig.getDevice(edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolating2P.RED_LED);
        end
        
        function value = get.blueLed(obj)
            value = obj.rig.getDevice(edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolating2P.BLUE_LED);
        end
        
        function value = get.uvLed(obj)
            value = obj.rig.getDevice(edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolating2P.UV_LED);
        end
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
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
                    'measurementRegion', [obj.preTime obj.preTime+obj.stimTime]);
            else
                obj.showFigure('edu.washington.riekelab.figures.DualResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualMeanResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, obj.rig.getDevice(obj.amp2), {@mean, @var}, ...
                    'baselineRegion1', [0 obj.preTime], ...
                    'measurementRegion1', [obj.preTime obj.preTime+obj.stimTime], ...
                    'baselineRegion2', [0 obj.preTime], ...
                    'measurementRegion2', [obj.preTime obj.preTime+obj.stimTime]);
            end
            
            rbuMean = obj.lmsToRbu * obj.lmsMeanIsomerizations;

            obj.redLed.background = symphonyui.core.Measurement(rbuMean(1), obj.redLed.background.displayUnits);
            obj.blueLed.background = symphonyui.core.Measurement(rbuMean(2), obj.blueLed.background.displayUnits);
            obj.uvLed.background = symphonyui.core.Measurement(rbuMean(3), obj.uvLed.background.displayUnits);
        end
        
        function stim = createLedStimulus(obj, seed, voltageMean, voltageStdv, deviceDisplayUnits)
            gen = edu.washington.riekelab.stimuli.GaussianNoiseGeneratorV2();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.stDev = voltageStdv;
            gen.freqCutoff = obj.frequencyCutoff;
            gen.numFilters = obj.numberOfFilters;
            gen.mean = voltageMean;
            gen.seed = seed;
            gen.sampleRate = obj.sampleRate;
            gen.units = deviceDisplayUnits;
            
            if strcmp(gen.units, symphonyui.core.Measurement.NORMALIZED)
                gen.upperLimit = 1;
                gen.lowerLimit = 0;
            else
                gen.upperLimit = 10.239;
                gen.lowerLimit = -10.24;
            end
            
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            persistent seed;
            if ~obj.useRandomSeed
                seed = 0;
            elseif mod(obj.numEpochsPrepared - 1, obj.repeatsPerStdv) == 0
                seed = RandStream.shuffleSeed;
            end
            
            rbuMean = obj.lmsToRbu * obj.lmsMeanIsomerizations;
            rbuStdv = obj.lmsToRbu * obj.lmsStdvIsomerizations;
            
            redStim = obj.createLedStimulus(seed, rbuMean(1), rbuStdv(1), obj.redLed.background.displayUnits);
            blueStim = obj.createLedStimulus(seed, rbuMean(2), rbuStdv(2), obj.blueLed.background.displayUnits);
            uvStim = obj.createLedStimulus(seed, rbuMean(3), rbuStdv(3), obj.uvLed.background.displayUnits);
            
            epoch.addParameter('seed', seed);
            
            epoch.addStimulus(obj.redLed, redStim);
            epoch.addStimulus(obj.blueLed, blueStim);
            epoch.addStimulus(obj.uvLed, uvStim);
            
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            interval.addDirectCurrentStimulus(obj.redLed, obj.redLed.background, obj.interpulseInterval, obj.sampleRate);
            interval.addDirectCurrentStimulus(obj.blueLed, obj.blueLed.background, obj.interpulseInterval, obj.sampleRate);
            interval.addDirectCurrentStimulus(obj.uvLed, obj.uvLed.background, obj.interpulseInterval, obj.sampleRate);
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