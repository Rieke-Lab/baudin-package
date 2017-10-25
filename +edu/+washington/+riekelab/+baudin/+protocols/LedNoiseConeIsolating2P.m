classdef LedNoiseConeIsolating2P < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Presents Gaussian noise stimuli intended to stimulate a signle cone.
    % Stimulus will have a specified mean number of isomerizations as well
    % as a noise standard deviation - also in isomerizations.
    
    properties
        redLedIsomPerVoltS              % S cone isomerizations per volt delivered to red led with given settings
        redLedIsomPerVoltM              % M cone isomerizations per volt delivered to red led with given settings
        redLedIsomPerVoltL              % L cone isomerizations per volt delivered to red led with given settings
        blueLedIsomPerVoltS             % S cone isomerizations per volt delivered to blue led with given settings
        blueLedIsomPerVoltM             % M cone isomerizations per volt delivered to blue led with given settings
        blueLedIsomPerVoltL             % L cone isomerizations per volt delivered to blue led with given settings
        uvLedIsomPerVoltS               % S cone isomerizations per volt delivered to uv led with given settings
        uvLedIsomPerVoltM               % M cone isomerizations per volt delivered to uv led with given settings
        uvLedIsomPerVoltL               % L cone isomerizations per volt delivered to uv led with given settings
        preTime = 100                   % Noise leading duration (ms)
        stimTime = 600                  % Noise duration (ms)
        tailTime = 100                  % Noise trailing duration (ms)
        frequencyCutoff = 60            % Noise frequency cutoff for smoothing (Hz)
        numberOfFilters = 4             % Number of filters in cascade for noise smoothing
        meanIsomerizations = 1000       % Mean number of isomerizations for noise and background in units of isomerizations
        stdvIsomerizations = 500        % Noise standard deviation in units of isomerizations
        coneTypeToStimulate             % Type of cone that this stimulus will isolate
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
    end
    
    properties (Hidden)
        coneTypeToStimulateType = symphonyui.core.PropertyType( ...
            'char',  ...
            'row', ...
            {edu.washington.riekelab.baudin.protocols.LedNoiseConIsolating2P.S_CONE, ...
            edu.washington.riekelab.baudin.protocols.LedNoiseConIsolating2P.M_CONE, ...
            edu.washington.riekelab.baudin.protocols.LedNoiseConIsolating2P.L_CONE})
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
            value = zeros(1, 3);
            value(obj.coneTypeToStimulateIndex) = obj.meanIsomerizations;
        end
        
        
        function value = get.lmsStdvIsomerizations(obj)
            value = zeros(1, 3);
            value(obj.coneTypeToStimulateIndex) = obj.stdvIsomerizations;
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
                obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp), ...
                    'groupBy', {'stdv'});
                obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
                    'baselineRegion', [0 obj.preTime], ...
                    'measurementRegion', [obj.preTime obj.preTime+obj.stimTime]);
            else
                obj.showFigure('edu.washington.riekelab.figures.DualResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualMeanResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2), ...
                    'groupBy1', {'stdv'}, ...
                    'groupBy2', {'stdv'});
                obj.showFigure('edu.washington.riekelab.figures.DualResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, obj.rig.getDevice(obj.amp2), {@mean, @var}, ...
                    'baselineRegion1', [0 obj.preTime], ...
                    'measurementRegion1', [obj.preTime obj.preTime+obj.stimTime], ...
                    'baselineRegion2', [0 obj.preTime], ...
                    'measurementRegion2', [obj.preTime obj.preTime+obj.stimTime]);
            end
            
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(obj.lightMean, device.background.displayUnits);
        end
        
        function stim = createLedStimulus(obj, seed, voltageMean, voltageStdv)
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
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
            
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
            
            redStim = obj.createLedStimulus(seed, rbuMean(1), rbuStdv(1));
            blueStim = obj.createLedStimulus(seed, rbuMean(2), rbuStdv(2));
            uvStim = obj.createLedStimulus(seed, rbuMean(3), rbuStdv(3));
            
            epoch.addParameter('seed', seed);
            
            epoch.addStimulus( ...
                obj.rig.getDevice(edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolating2P.RED_LED), redStim);
            epoch.addStimulus( ...
                obj.rig.getDevice(edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolating2P.BLUE_LED), blueStim);
            epoch.addStimulus( ...
                obj.rig.getDevice(edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolating2P.UV_LED), uvStim);
            
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